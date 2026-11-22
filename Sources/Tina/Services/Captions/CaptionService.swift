// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import Carbon.HIToolbox
import Combine
import CoreMedia
import Foundation
import Speech

/// Turns the Mac's own sound into on-screen captions. The audio comes from
/// the recorder's process tap, so it hears every app's mix without capturing
/// the screen; recognition is Speech with on-device recognition required.
///
/// The service owns four lifetimes: the tap, the recognizer request, the
/// caption bar and the session file. Starting creates all four, stopping
/// releases them together, and a feature uninstall follows the same path.
/// Main-thread confined: the audio callback touches only the atomic sound
/// stamp, and the async tap startup hops back through the main queue before
/// mutating anything. `@unchecked Sendable` states that confinement for the
/// startup Task's capture checks.
final class CaptionService: ObservableObject, @unchecked Sendable {
    static let shared = CaptionService()

    enum Phase: Equatable {
        case idle
        case starting
        case listening
        case stopping
        case failed(Failure)
    }

    enum Failure: Equatable {
        case osTooOld
        case speechDenied
        case onDeviceUnavailable
        case speechUnavailable
        case recorderRunning
        case audioUnavailable
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    /// The newest partial or final line. Empty while silent, which is what
    /// fades the bar after `CaptionSupport.silenceFadeSeconds`.
    @Published private(set) var liveText = ""
    @Published private(set) var session: CaptionSession?
    @Published private(set) var recentSessions: [CaptionSession] = []
    @Published private(set) var localeIdentifier = ""
    /// A one-shot explanation for the panel: an export failure, an unsupported
    /// language, or a recognition error. Never a silent failure.
    @Published private(set) var notice: String?
    @Published private(set) var registrationFailed = false

    var isListening: Bool {
        phase == .listening || phase == .starting
    }

    var isBusy: Bool {
        phase == .starting || phase == .stopping
    }

    private let overlay = CaptionOverlayController()
    private let lastSoundHost = RecorderAudioHostTime()
    private var tap: RecorderSystemAudioTap?
    private var recognizer: CaptionRecognizer?
    private var sessionStartedAt: Date?
    private var silenceTimer: Timer?
    private var recorderCancellable: AnyCancellable?
    private var persistedSegmentCount = 0
    /// Invalidates a start that is still waiting for permission or for the
    /// audio tap when the user stops it. Without this, the late continuation
    /// would install a tap nobody asked for.
    private var startToken = 0
    private var customDirectory: URL?
    private var customDirectoryAccess = false
    private lazy var sessionStore = resolveSessionStore()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var registeredShortcut: GlobalShortcut?

    private var strings: CaptionFeatureStrings {
        FeatureStrings.captions(L10n.shared.language)
    }

    private init() {
        // Speech is not touched until Settings or Start asks for the list;
        // merely installing the feature must not enumerate every locale or
        // bring the recorder service to life.
        localeIdentifier = UserDefaults.standard.string(forKey: DefaultsKey.captionsLocale) ?? ""
        if localeIdentifier.isEmpty {
            localeIdentifier = Locale.preferredLanguages.first ?? "en-US"
        }
        resolveCustomDirectory()
        recentSessions = sessionStore.loadAll(limit: 10)
    }

    /// Resolves the saved system language against the on-device list. Called
    /// when the settings page appears, and again when listening starts.
    func prepareLocales() {
        let resolved = resolvedLocale().identifier
        if localeIdentifier != resolved { localeIdentifier = resolved }
    }

    /// A recording started from anywhere else is the one conflict this
    /// feature cannot share the tap with. Subscribed only while listening, so
    /// an idle caption feature never instantiates the recorder.
    private func observeRecorder() {
        recorderCancellable = ScreenRecorderService.shared.$isRecording
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] recording in
                guard let self, recording, self.isListening else { return }
                self.stop()
                self.phase = .failed(.recorderRunning)
                self.notice = self.message(for: .recorderRunning)
            }
    }

    // MARK: - Availability

    /// Called whenever the hub availability or a caption preference changes.
    func syncWithPreferences() {
        let defaults = UserDefaults.standard
        guard AppFeature.captions.isAvailable,
              defaults.bool(forKey: DefaultsKey.captionsEnabled) else {
            if isListening || phase == .stopping { stop() }
            unregisterHotkey()
            return
        }
        if defaults.bool(forKey: DefaultsKey.captionsShortcutEnabled) {
            registerHotkey()
        } else {
            unregisterHotkey()
        }
    }

    // MARK: - Listening

    func toggle() {
        if isListening {
            stop()
        } else {
            start()
        }
    }

    func start() {
        guard AppFeature.captions.isAvailable else { return }
        guard UserDefaults.standard.bool(forKey: DefaultsKey.captionsEnabled) else {
            // The master switch lives in Settings; starting from the panel is
            // still one click, so it turns that switch on rather than doing
            // nothing.
            UserDefaults.standard.set(true, forKey: DefaultsKey.captionsEnabled)
            start()
            return
        }
        guard !isListening, phase != .stopping else { return }
        guard #available(macOS 14.4, *) else {
            fail(.osTooOld)
            return
        }
        guard !ScreenRecorderService.shared.isRecording else {
            fail(.recorderRunning)
            return
        }
        notice = nil
        phase = .starting
        startToken += 1
        let token = startToken
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            beginListening(token: token)
        case .notDetermined:
            phase = .starting
            Permissions.shared.requestSpeechRecognition { [weak self] state in
                guard let self, self.startToken == token, self.phase == .starting else { return }
                if state == .granted {
                    self.beginListening(token: token)
                } else {
                    self.fail(.speechDenied)
                }
            }
        case .denied, .restricted:
            fail(.speechDenied)
        @unknown default:
            fail(.speechUnavailable)
        }
    }

    private func beginListening(token: Int) {
        guard startToken == token, phase == .starting else { return }
        let started = Date()
        let locale = resolvedLocale()
        guard let recognizer = CaptionRecognizer(locale: locale, sessionStartedAt: started) else {
            fail(.speechUnavailable)
            return
        }
        guard recognizer.supportsOnDeviceRecognition else {
            fail(.onDeviceUnavailable)
            return
        }
        let newSession = CaptionSession(startedAt: started, localeIdentifier: locale.identifier)
        Task { [weak self] in
            guard let tap = await RecorderSystemAudioTap.make(hearing: nil) else {
                DispatchQueue.main.async { self?.fail(.audioUnavailable) }
                return
            }
            let reading = await tap.start(synchronizingTo: CMClockGetHostTimeClock())
            DispatchQueue.main.async {
                guard let self, self.startToken == token, self.phase == .starting else {
                    Task { await tap.stop() }
                    return
                }
                guard reading else {
                    Task { await tap.stop() }
                    self.fail(.audioUnavailable)
                    return
                }
                // A recording may have started while the tap was being built.
                guard !ScreenRecorderService.shared.isRecording else {
                    Task { await tap.stop() }
                    self.fail(.recorderRunning)
                    return
                }
                self.tap = tap
                self.recognizer = recognizer
                self.session = newSession
                self.sessionStartedAt = started
                self.localeIdentifier = locale.identifier
                self.persistedSegmentCount = 0
                self.liveText = ""
                self.phase = .listening
                self.lastSoundHost.value = mach_absolute_time()
                self.bind(recognizer: recognizer, tap: tap)
                recognizer.start()
                self.observeRecorder()
                self.startSilenceTimer()
                self.overlay.show(service: self)
                self.notice = nil
            }
        }
    }

    private func bind(recognizer: CaptionRecognizer, tap: RecorderSystemAudioTap) {
        let lastSoundHost = self.lastSoundHost
        // The audio callback runs on the audio system's thread. It touches
        // only the atomic sound stamp and hands the copied buffer to the
        // recognizer's own queue; every other field stays main-thread.
        tap.onSample = { sample in
            if RecorderAudioProbe.containsSound(sample) {
                lastSoundHost.value = mach_absolute_time()
            }
            guard let buffer = CaptionAudioBuffer.pcmBuffer(from: sample) else { return }
            recognizer.append(buffer)
        }
        tap.onReaderLost = { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.isListening else { return }
                self.fail(.audioUnavailable)
            }
        }
        recognizer.onPartial = { [weak self] text in
            guard let self, self.phase == .listening else { return }
            self.show(text)
        }
        recognizer.onFinal = { [weak self] segments in
            guard let self, self.phase == .listening else { return }
            guard var current = self.session else { return }
            current.segments = CaptionSupport.appending(segments, to: current.segments)
            self.session = current
            let text = segments.map(\.text).joined(separator: " ")
            self.show(text)
            self.persistIncrementally(current)
        }
        recognizer.onFailure = { [weak self] failure in
            guard let self else { return }
            switch failure {
            case .denied: self.fail(.speechDenied)
            case .unavailable: self.fail(.speechUnavailable)
            case .onDeviceUnavailable: self.fail(.onDeviceUnavailable)
            case .failed(let message): self.fail(.failed(message))
            }
        }
    }

    private func show(_ text: String) {
        let normalized = CaptionSupport.normalizedText(text)
        if liveText != normalized { liveText = normalized }
        overlay.setActive(!normalized.isEmpty)
    }

    func stop() {
        guard phase != .idle || tap != nil || recognizer != nil else { return }
        startToken += 1
        phase = .stopping
        commitLiveLine()
        teardown()
        finalizeSession()
        phase = .idle
        notice = nil
    }

    private func fail(_ failure: Failure) {
        startToken += 1
        let wasRunning = tap != nil || recognizer != nil
        if wasRunning {
            phase = .stopping
            commitLiveLine()
            teardown()
            finalizeSession()
        }
        phase = .failed(failure)
        notice = message(for: failure)
    }

    private func teardown() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        recorderCancellable = nil
        recognizer?.stop()
        recognizer = nil
        if let tap {
            Task { await tap.stop() }
        }
        tap = nil
        overlay.hide()
        if !liveText.isEmpty { liveText = "" }
    }

    /// The newest partial line is the only copy of the last words when Stop
    /// arrives, so it is committed before the recognizer is torn down. The
    /// recognizer's own flush then merges into the same line rather than
    /// adding a second one.
    private func commitLiveLine() {
        guard var current = session, !liveText.isEmpty else { return }
        let start = current.segments.last?.end
            ?? max(0, Date().timeIntervalSince(current.startedAt) - 1)
        let end = max(start + 0.5, Date().timeIntervalSince(current.startedAt))
        guard let segment = CaptionSupport.fallbackSegment(text: liveText, start: start, end: end)
        else { return }
        current.segments = CaptionSupport.appending([segment], to: current.segments)
        session = current
    }

    private func finalizeSession() {
        guard var finished = session else { return }
        finished.endedAt = Date()
        session = nil
        sessionStartedAt = nil
        persistedSegmentCount = 0
        if finished.hasContent,
           UserDefaults.standard.bool(forKey: DefaultsKey.captionsAutoSave) {
            _ = try? sessionStore.save(finished)
        }
        refreshRecent()
    }

    /// Long meetings should survive a crash, not only a clean stop. The file
    /// is rewritten as finalized lines arrive, at a coarse interval.
    private func persistIncrementally(_ current: CaptionSession) {
        guard UserDefaults.standard.bool(forKey: DefaultsKey.captionsAutoSave),
              current.segments.count >= persistedSegmentCount + 5 else { return }
        persistedSegmentCount = current.segments.count
        var copy = current
        copy.endedAt = Date()
        _ = try? sessionStore.save(copy)
    }

    // MARK: - Silence

    private func startSilenceTimer() {
        silenceTimer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, self.phase == .listening else { return }
            guard Self.hostSeconds(since: self.lastSoundHost.value) >= CaptionSupport.silenceFadeSeconds
            else { return }
            if !self.liveText.isEmpty { self.liveText = "" }
            self.overlay.setActive(false)
        }
        RunLoop.main.add(timer, forMode: .common)
        silenceTimer = timer
    }

    private static func hostSeconds(since stamp: UInt64) -> Double {
        guard stamp != 0 else { return 0 }
        let now = mach_absolute_time()
        let ticks = now >= stamp ? now - stamp : 0
        var info = mach_timebase_info()
        guard mach_timebase_info(&info) == KERN_SUCCESS, info.denom != 0 else { return 0 }
        return Double(ticks) * Double(info.numer) / Double(info.denom) / 1_000_000_000
    }

    // MARK: - Language

    /// Locales this Mac can recognize without a network. Computed once; the
    /// list only changes with a macOS update.
    static let availableLocales: [Locale] = {
        SFSpeechRecognizer.supportedLocales()
            .filter { SFSpeechRecognizer(locale: $0)?.supportsOnDeviceRecognition == true }
            .sorted {
                Locale.current.localizedString(forIdentifier: $0.identifier) ?? $0.identifier
                    < Locale.current.localizedString(forIdentifier: $1.identifier) ?? $1.identifier
            }
    }()

    func resolvedLocale() -> Locale {
        let saved = UserDefaults.standard.string(forKey: DefaultsKey.captionsLocale) ?? ""
        if !saved.isEmpty,
           let match = Self.availableLocales.first(where: { $0.identifier == saved }) {
            return match
        }
        let system = Locale.preferredLanguages.first ?? "en-US"
        if let exact = Self.availableLocales.first(where: {
            $0.identifier.caseInsensitiveCompare(system) == .orderedSame
        }) {
            return exact
        }
        let language = Locale(identifier: system).language.languageCode?.identifier
            ?? system.split(separator: "-").first.map(String.init) ?? "en"
        if let byLanguage = Self.availableLocales.first(where: {
            $0.language.languageCode?.identifier == language
        }) {
            return byLanguage
        }
        return Self.availableLocales.first ?? Locale(identifier: "en-US")
    }

    func setLocale(_ locale: Locale) {
        UserDefaults.standard.set(locale.identifier, forKey: DefaultsKey.captionsLocale)
        localeIdentifier = locale.identifier
        if isListening {
            stop()
            start()
        }
    }

    func localeName(_ locale: Locale) -> String {
        Locale.current.localizedString(forIdentifier: locale.identifier)
            ?? locale.identifier
    }

    // MARK: - Sessions

    func refreshRecent() {
        let loaded = sessionStore.loadAll(limit: 10)
        if loaded != recentSessions { recentSessions = loaded }
    }

    @discardableResult
    func export(_ session: CaptionSession, as format: CaptionExportFormat) -> URL? {
        do {
            guard let url = try sessionStore.export(session, as: format) else { return nil }
            notice = nil
            return url
        } catch {
            notice = strings.exportFailed
            return nil
        }
    }

    func copyAllText(_ session: CaptionSession) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(session.spokenText, forType: .string)
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func delete(_ session: CaptionSession) {
        do {
            try sessionStore.delete(session)
            refreshRecent()
        } catch {
            notice = strings.exportFailed
        }
    }

    func clearHistory() {
        do {
            try sessionStore.deleteAll()
            refreshRecent()
        } catch {
            notice = strings.exportFailed
        }
    }

    var folderPath: String {
        customDirectory?.path ?? sessionStore.directory.path
    }

    var isUsingCustomFolder: Bool { customDirectory != nil }

    func setFolder(_ url: URL) {
        stopCustomDirectoryAccess()
        customDirectory = url
        UserDefaults.standard.set(url.path, forKey: DefaultsKey.captionsFolderPath)
        if let bookmark = try? url.bookmarkData(options: [.withSecurityScope],
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil) {
            UserDefaults.standard.set(bookmark, forKey: DefaultsKey.captionsFolderBookmark)
        }
        customDirectoryAccess = url.startAccessingSecurityScopedResource()
        sessionStore = CaptionSessionStore(directory: url)
        refreshRecent()
    }

    func resetFolder() {
        stopCustomDirectoryAccess()
        customDirectory = nil
        UserDefaults.standard.removeObject(forKey: DefaultsKey.captionsFolderBookmark)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.captionsFolderPath)
        sessionStore = CaptionSessionStore()
        refreshRecent()
    }

    private func resolveCustomDirectory() {
        guard let data = UserDefaults.standard.data(forKey: DefaultsKey.captionsFolderBookmark) else {
            return
        }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data,
                                 options: [.withSecurityScope],
                                 relativeTo: nil,
                                 bookmarkDataIsStale: &stale) else { return }
        customDirectory = url
        customDirectoryAccess = url.startAccessingSecurityScopedResource()
        if stale,
           let refreshed = try? url.bookmarkData(options: [.withSecurityScope],
                                                  includingResourceValuesForKeys: nil,
                                                  relativeTo: nil) {
            UserDefaults.standard.set(refreshed, forKey: DefaultsKey.captionsFolderBookmark)
        }
    }

    private func resolveSessionStore() -> CaptionSessionStore {
        if let customDirectory { return CaptionSessionStore(directory: customDirectory) }
        return CaptionSessionStore()
    }

    private func stopCustomDirectoryAccess() {
        guard customDirectoryAccess, let customDirectory else {
            customDirectoryAccess = false
            return
        }
        customDirectory.stopAccessingSecurityScopedResource()
        customDirectoryAccess = false
    }

    // MARK: - Messages

    func message(for failure: Failure) -> String {
        switch failure {
        case .osTooOld: return strings.unsupportedOS
        case .speechDenied: return strings.speechDenied
        case .onDeviceUnavailable: return strings.onDeviceUnavailable
        case .speechUnavailable: return strings.speechUnavailable + " " + strings.dictationHint
        case .recorderRunning: return strings.recorderConflict
        case .audioUnavailable: return strings.audioUnavailable
        case .failed(let message): return message.isEmpty ? strings.speechUnavailable : message
        }
    }

    func clearNotice() {
        if notice != nil { notice = nil }
    }

    /// The panel and Settings both offer this, so the saved place is reset in
    /// one helper rather than by writing the defaults in two views.
    func resetOverlayPosition() {
        overlay.resetPosition()
    }

    // MARK: - Shortcut

    private func registerHotkey() {
        let shortcut = GlobalShortcut.saved(for: DefaultsKey.captionsShortcut,
                                            fallback: .captionsDefault)
        if hotKeyRef != nil, registeredShortcut == shortcut { return }
        unregisterHotkey()
        if eventHandler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                     eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetEventDispatcherTarget(), { _, event, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                var id = EventHotKeyID()
                if let event {
                    GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                      EventParamType(typeEventHotKeyID), nil,
                                      MemoryLayout<EventHotKeyID>.size, nil, &id)
                }
                guard id.signature == 0x5655_4341, id.id == 9
                else { return OSStatus(eventNotHandledErr) }
                let service = Unmanaged<CaptionService>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { service.toggle() }
                return noErr
            }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        }
        let id = EventHotKeyID(signature: 0x5655_4341, id: 9) // 'VUCA'
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.carbonKeyCode, shortcut.carbonModifiers, id,
                                         GetEventDispatcherTarget(), 0, &ref)
        if status == noErr, let ref {
            hotKeyRef = ref
            registeredShortcut = shortcut
            registrationFailed = false
            SystemShortcutTakeover.claim(DefaultsKey.captionsShortcut, shortcut: shortcut)
        } else {
            hotKeyRef = nil
            registeredShortcut = nil
            registrationFailed = true
        }
    }

    /// Lets the shortcut field record the combination this feature uses.
    func suspendShortcut() {
        unregisterHotkey()
    }

    private func unregisterHotkey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            SystemShortcutTakeover.release(DefaultsKey.captionsShortcut)
        }
        hotKeyRef = nil
        registeredShortcut = nil
        registrationFailed = false
    }
}
