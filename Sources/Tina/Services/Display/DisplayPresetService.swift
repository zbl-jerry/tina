// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation
import os

/// Named snapshots of the connected displays: their resolution, brightness,
/// monitor speaker volume and which display owns the menu bar. A preset can be
/// applied from the panel or Settings, from its own global shortcut, or
/// automatically when a display connects or disconnects.
///
/// The service belongs to the Displays feature. It stops watching, applying
/// and holding hotkeys when that feature is unavailable, and it reads display
/// topology itself so resolution and main-display changes work even while the
/// brightness sliders are switched off.
final class DisplayPresetService: ObservableObject {
    static let shared = DisplayPresetService()

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "tina",
                                    category: "display-presets")
    /// How long the display server is given to settle after a connection or a
    /// disconnection before an automatic rule is judged.
    private static let topologySettleDelay: TimeInterval = 2
    /// A preset that changes resolutions produces another topology
    /// notification. Ignore automatic rules for a moment so it cannot trigger
    /// itself.
    private static let autoApplyQuietPeriod: TimeInterval = 8
    /// Brightness and volume wait for the brightness pipeline to notice a
    /// resolution change, so its routes belong to the new arrangement.
    private static let levelApplyDelay: TimeInterval = 1

    @Published private(set) var presets: [DisplayPreset] = []
    @Published private(set) var lastReport: DisplayPresetReport?
    @Published private(set) var isApplying = false

    /// Identity of the display list an automatic rule is compared against.
    private var knownOnlineFingerprints: Set<String> = []
    private var screenObserver: NSObjectProtocol?
    private var topologyCheck: DispatchWorkItem?
    private var suppressAutomaticUntil = Date.distantPast
    private var running = false
    private var currentReportID: UUID?

    private var hotkeys: [UUID: DisplayPresetHotkey] = [:]
    private var nextHotkeyID: UInt32 = 1
    private var captureObserver: NSObjectProtocol?

    private init() {
        captureObserver = NotificationCenter.default.addObserver(
            forName: ShortcutCapture.captureDidBeginNotification, object: nil, queue: .main) { [weak self] _ in
            self?.suspendShortcuts()
        }
    }

    // MARK: - Lifecycle

    /// Called by the Displays feature binding at launch, when its availability
    /// changes, and after shortcut recording releases the app's global keys.
    func syncWithPreferences() {
        guard AppFeature.brightness.isAvailable else {
            stop()
            return
        }
        running = true
        reload()
        syncAutomaticRules()
        syncHotkeys()
        if knownOnlineFingerprints.isEmpty {
            knownOnlineFingerprints = Self.onlineFingerprints()
        }
    }

    func stop() {
        running = false
        removeScreenObserver()
        topologyCheck?.cancel()
        topologyCheck = nil
        suspendShortcuts()
        presets = []
        lastReport = nil
        isApplying = false
        currentReportID = nil
        knownOnlineFingerprints = []
    }

    /// While a shortcut field is recording, every global key has to reach it
    /// instead of firing a preset. The Displays feature binding registers the
    /// keys again when recording ends.
    func suspendShortcuts() {
        for hotkey in hotkeys.values { hotkey.unregister() }
        hotkeys.removeAll()
    }

    // MARK: - Presets

    private func reload() {
        let stored = DisplayPresetSupport.decode(
            UserDefaults.standard.data(forKey: DefaultsKey.displayPresets))
        if stored != presets { presets = stored }
    }

    private func persist(_ next: [DisplayPreset]) {
        presets = Array(next.prefix(DisplayPresetSupport.maximumPresets))
        UserDefaults.standard.set(DisplayPresetSupport.encode(presets),
                                  forKey: DefaultsKey.displayPresets)
        syncAutomaticRules()
        syncHotkeys()
    }

    /// Captures every display Tina can see and appends a new preset. Nil when
    /// no display reports a usable identity.
    @discardableResult
    func createPreset(name: String, symbol: String,
                      trigger: DisplayPreset.Trigger?) -> DisplayPreset? {
        let captured = captureDisplays()
        guard !captured.isEmpty else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let main = Self.mainDisplayFingerprint()
        let preset = DisplayPreset(
            id: UUID(),
            name: trimmed.isEmpty
                ? FeatureStrings.displayPreset(L10n.shared.language).defaultName : trimmed,
            symbol: DisplayPresetSupport.symbols.contains(symbol)
                ? symbol : DisplayPresetSupport.defaultSymbol,
            displays: captured,
            mainDisplayFingerprint: captured.contains { $0.fingerprint == main } ? main : nil,
            shortcut: nil,
            trigger: trigger)
        persist(presets + [preset])
        return presets.last
    }

    /// Replaces the saved values with what is on screen now, keeping the name,
    /// icon, shortcut and automatic rule.
    func updateFromCurrent(id: UUID) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        let captured = captureDisplays()
        guard !captured.isEmpty else { return }
        var preset = presets[index]
        preset.displays = captured
        let main = Self.mainDisplayFingerprint()
        preset.mainDisplayFingerprint = captured.contains { $0.fingerprint == main } ? main : nil
        persist(presets.with(preset, at: index))
    }

    func updateDetails(id: UUID, name: String, symbol: String,
                       trigger: DisplayPreset.Trigger?) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        var preset = presets[index]
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        preset.name = trimmed.isEmpty
            ? FeatureStrings.displayPreset(L10n.shared.language).defaultName : trimmed
        preset.symbol = DisplayPresetSupport.symbols.contains(symbol)
            ? symbol : DisplayPresetSupport.defaultSymbol
        preset.trigger = trigger
        persist(presets.with(preset, at: index))
    }

    func setShortcut(_ shortcut: GlobalShortcut?, for id: UUID) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        var preset = presets[index]
        preset.shortcut = shortcut?.storageValue
        persist(presets.with(preset, at: index))
    }

    func delete(id: UUID) {
        persist(presets.filter { $0.id != id })
        if lastReport?.presetID == id { lastReport = nil }
    }

    func dismissReport() {
        lastReport = nil
    }

    // MARK: - Capturing

    /// A display as the preset service sees it, without touching the
    /// brightness feature's routes.
    private struct LiveDisplay {
        let id: CGDirectDisplayID
        let name: String
        let isActive: Bool
        let isBuiltIn: Bool
        let fingerprint: String?
    }

    private func captureDisplays() -> [DisplayPreset.Display] {
        let brightnessByID = Dictionary(uniqueKeysWithValues:
            BrightnessService.shared.displays.map { ($0.id, $0) })
        return Self.liveDisplays().compactMap { live in
            guard let fingerprint = live.fingerprint else { return nil }
            let mode = live.isActive ? CGDisplayCopyDisplayMode(live.id) : nil
            let mirrored = CGDisplayMirrorsDisplay(live.id) != 0
            let resolution = mode.flatMap {
                mirrored ? nil : DisplayPresetSupport.currentResolution(of: $0)
            }
            let brightness = brightnessByID[live.id]
            return DisplayPreset.Display(
                fingerprint: fingerprint,
                name: live.name,
                isBuiltIn: live.isBuiltIn,
                resolution: resolution,
                brightness: live.isActive && brightness?.method != nil
                    ? brightness?.brightness : nil,
                volume: live.isActive ? brightness?.audio?.volume : nil,
                muted: live.isActive ? brightness?.audio?.muted : nil)
        }
    }

    private static func mainDisplayFingerprint() -> String? {
        DisplayPresetSupport.fingerprint(of: CGMainDisplayID())
    }

    /// Displays an automatic rule can watch: everything connected now.
    func triggerCandidates() -> [DisplayPresetCandidate] {
        Self.liveDisplays().compactMap { live in
            guard let fingerprint = live.fingerprint else { return nil }
            return DisplayPresetCandidate(fingerprint: fingerprint, name: live.name)
        }
    }

    private static func liveDisplays() -> [LiveDisplay] {
        let names = screenNames()
        let active = activeDisplayIDs()
        return onlineDisplayIDs().map { id in
            LiveDisplay(id: id,
                        name: names[id] ?? Self.displayName(id),
                        isActive: active.contains(id),
                        isBuiltIn: CGDisplayIsBuiltin(id) != 0,
                        fingerprint: DisplayPresetSupport.fingerprint(of: id))
        }
    }

    private static func onlineDisplayIDs() -> [CGDirectDisplayID] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 32)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(32, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }

    private static func activeDisplayIDs() -> Set<CGDirectDisplayID> {
        var ids = [CGDirectDisplayID](repeating: 0, count: 32)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(32, &ids, &count) == .success else { return [] }
        return Set(ids.prefix(Int(count)))
    }

    private static func onlineFingerprints() -> Set<String> {
        Set(onlineDisplayIDs().compactMap { DisplayPresetSupport.fingerprint(of: $0) })
    }

    private static func screenNames() -> [CGDirectDisplayID: String] {
        var names: [CGDirectDisplayID: String] = [:]
        for screen in NSScreen.screens {
            guard let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                             as? NSNumber)?.uint32Value else { continue }
            names[id] = screen.localizedName
        }
        return names
    }

    private static func displayName(_ id: CGDirectDisplayID) -> String {
        if let info = BrightnessBridge.createInfoDictionary?(id)?.takeRetainedValue() as? NSDictionary,
           let names = info["DisplayProductName"] as? [String: String],
           let name = names["en_US"] ?? names.first?.value {
            return name
        }
        return CGDisplayIsBuiltin(id) != 0 ? "Built-in Display" : "Display"
    }

    // MARK: - Applying

    /// Applies a preset by id; the panel chips call this directly.
    func apply(id: UUID) {
        guard let preset = presets.first(where: { $0.id == id }) else { return }
        apply(preset)
    }

    func apply(_ preset: DisplayPreset) {
        guard running else { return }
        let reportID = UUID()
        currentReportID = reportID
        isApplying = true
        suppressAutomaticUntil = Date().addingTimeInterval(Self.autoApplyQuietPeriod)
        lastReport = nil

        let live = Self.liveDisplays()
        var report = DisplayPresetReport(id: reportID, presetID: preset.id,
                                         presetName: preset.name)
        var used = Set<CGDirectDisplayID>()
        var resolved: [(entry: DisplayPreset.Display, live: LiveDisplay)] = []
        for entry in preset.displays {
            if let id = DisplayPresetSupport.match(
                entry,
                among: live.map { (id: $0.id, fingerprint: $0.fingerprint,
                                   isBuiltIn: $0.isBuiltIn) },
                used: &used),
               let matched = live.first(where: { $0.id == id }) {
                resolved.append((entry, matched))
            } else {
                report.failures.append(.init(kind: .notConnected,
                                             displayName: DisplayPresetSupport.displayLabel(entry)))
            }
        }

        report.failures += applyResolutions(resolved)

        if !applyMainDisplay(preset, resolved: resolved),
           preset.mainDisplayFingerprint != nil {
            let name = preset.displays.first {
                $0.fingerprint == preset.mainDisplayFingerprint
            }.map(DisplayPresetSupport.displayLabel)
                ?? FeatureStrings.displayPreset(L10n.shared.language).defaultName
            report.failures.append(.init(kind: .mainDisplayFailed, displayName: name))
        }

        isApplying = false
        publish(report)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.levelApplyDelay) { [weak self] in
            self?.applyLevels(resolved, reportID: reportID)
        }
    }

    private func applyLevels(_ resolved: [(entry: DisplayPreset.Display, live: LiveDisplay)],
                             reportID: UUID) {
        guard currentReportID == reportID else { return }
        // Read the routes now, after any resolution change has been rebuilt,
        // instead of trusting the display state from before the transaction.
        let brightnessByID = Dictionary(uniqueKeysWithValues:
            BrightnessService.shared.displays.map { ($0.id, $0) })
        let brightnessEnabled = AppFeature.brightness.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.brightnessControlEnabled)
        let volumeEnabled = brightnessEnabled
            && UserDefaults.standard.bool(forKey: DefaultsKey.displayVolumeEnabled)
        var added: [DisplayPresetReport.Failure] = []
        for (entry, live) in resolved {
            if brightnessEnabled, let brightness = entry.brightness {
                if let display = brightnessByID[live.id], display.method != nil, live.isActive {
                    BrightnessService.shared.setBrightness(brightness, for: live.id,
                                                          announces: false)
                } else {
                    added.append(.init(kind: .brightnessUnavailable,
                                       displayName: DisplayPresetSupport.displayLabel(entry)))
                }
            }
            if volumeEnabled, let volume = entry.volume {
                guard let audio = brightnessByID[live.id]?.audio else {
                    added.append(.init(kind: .volumeUnavailable,
                                       displayName: DisplayPresetSupport.displayLabel(entry)))
                    continue
                }
                BrightnessService.shared.requestSpeakers(
                    .set(volume: volume, muted: entry.muted),
                    target: audio.target) { [weak self] success in
                    guard !success else { return }
                    DispatchQueue.main.async {
                        self?.appendLateFailure(.init(kind: .volumeUnavailable,
                                                      displayName: DisplayPresetSupport.displayLabel(entry)),
                                                to: reportID)
                    }
                }
            }
        }
        finish(reportID: reportID, failures: added)
    }

    private func publish(_ report: DisplayPresetReport) {
        guard currentReportID == report.id else { return }
        lastReport = report
        if report.failed {
            Self.log.notice("preset \(report.presetName, privacy: .public) had \(report.failures.count) failed item(s)")
        }
    }

    private func finish(reportID: UUID, failures: [DisplayPresetReport.Failure]) {
        guard currentReportID == reportID, var report = lastReport, report.id == reportID else { return }
        report.failures += failures
        lastReport = report
    }

    private func appendLateFailure(_ failure: DisplayPresetReport.Failure, to reportID: UUID) {
        guard currentReportID == reportID, var report = lastReport, report.id == reportID else { return }
        report.failures.append(failure)
        lastReport = report
    }

    // MARK: - Resolution and main display

    private func applyResolutions(
        _ resolved: [(entry: DisplayPreset.Display, live: LiveDisplay)]
    ) -> [DisplayPresetReport.Failure] {
        var plan: [(live: LiveDisplay, mode: CGDisplayMode,
                    previous: CGDisplayMode, saved: DisplayPreset.Resolution)] = []
        var failures: [DisplayPresetReport.Failure] = []
        for (entry, live) in resolved {
            guard let saved = entry.resolution, live.isActive else { continue }
            if let current = CGDisplayCopyDisplayMode(live.id),
               DisplayPresetSupport.sameResolution(saved,
                                                   DisplayPresetSupport.currentResolution(of: current)) {
                continue
            }
            guard let modes = supportedModes(of: live.id) else {
                failures.append(.init(kind: .resolutionUnsupported,
                                      displayName: DisplayPresetSupport.displayLabel(entry)))
                continue
            }
            let values = modes.map { DisplayPresetSupport.currentResolution(of: $0) }
            guard let index = DisplayPresetSupport.bestModeIndex(for: saved, in: values),
                  let previous = CGDisplayCopyDisplayMode(live.id) else {
                failures.append(.init(kind: .resolutionUnsupported,
                                      displayName: DisplayPresetSupport.displayLabel(entry)))
                continue
            }
            plan.append((live, modes[index], previous, saved))
        }
        guard !plan.isEmpty else { return failures }

        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else {
            return failures + plan.map {
                .init(kind: .resolutionFailed, displayName: $0.live.name)
            }
        }
        var refused = false
        for item in plan where CGConfigureDisplayWithDisplayMode(config, item.live.id,
                                                                 item.mode, nil) != .success {
            refused = true
        }
        guard !refused, CGCompleteDisplayConfiguration(config, .permanently) == .success else {
            if refused { CGCancelDisplayConfiguration(config) }
            return failures + plan.map {
                .init(kind: .resolutionFailed, displayName: $0.live.name)
            }
        }

        var applied = 0
        for item in plan {
            let landed = CGDisplayCopyDisplayMode(item.live.id).map {
                DisplayPresetSupport.sameResolution(
                    item.saved, DisplayPresetSupport.currentResolution(of: $0))
            } ?? false
            if landed {
                applied += 1
            } else {
                // Put the display back before reporting: a mode that was
                // accepted but did not take effect is the case that can leave
                // a picture unusable.
                CGDisplaySetDisplayMode(item.live.id, item.previous, nil)
                failures.append(.init(kind: .resolutionFailed, displayName: item.live.name))
            }
        }
        if applied > 0 { suppressAutomaticUntil = Date().addingTimeInterval(Self.autoApplyQuietPeriod) }
        return failures
    }

    private func supportedModes(of id: CGDirectDisplayID) -> [CGDisplayMode]? {
        let options = [kCGDisplayShowDuplicateLowResolutionModes as String: true] as CFDictionary
        guard let modes = CGDisplayCopyAllDisplayModes(id, options) as? [CGDisplayMode]
        else { return nil }
        return modes
    }

    /// Moves the chosen display to the global origin, the public definition of
    /// the main display, translating every other active display by the same
    /// vector so the arrangement is kept.
    private func applyMainDisplay(
        _ preset: DisplayPreset,
        resolved: [(entry: DisplayPreset.Display, live: LiveDisplay)]
    ) -> Bool {
        guard let fingerprint = preset.mainDisplayFingerprint,
              let target = resolved.first(where: { $0.entry.fingerprint == fingerprint })?.live.id
        else { return false }
        guard CGMainDisplayID() != target else { return true }

        let active = Self.activeDisplayIDs().filter {
            CGDisplayMirrorsDisplay($0) == 0 && !Self.isVirtual($0)
        }
        guard active.contains(target) else { return false }
        let targetBounds = CGDisplayBounds(target)
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else { return false }
        for id in active {
            let bounds = CGDisplayBounds(id)
            let x = Int32((bounds.origin.x - targetBounds.origin.x).rounded())
            let y = Int32((bounds.origin.y - targetBounds.origin.y).rounded())
            guard CGConfigureDisplayOrigin(config, id, x, y) == .success else {
                CGCancelDisplayConfiguration(config)
                return false
            }
        }
        guard CGCompleteDisplayConfiguration(config, .permanently) == .success else { return false }
        return CGMainDisplayID() == target
    }

    private static func isVirtual(_ id: CGDirectDisplayID) -> Bool {
        guard let info = BrightnessBridge.createInfoDictionary?(id)?.takeRetainedValue()
                as? NSDictionary else { return false }
        return info["kCGDisplayIsVirtualDevice"] as? Bool ?? false
    }

    // MARK: - Automatic rules

    private func syncAutomaticRules() {
        guard running, AppFeature.brightness.isAvailable,
              presets.contains(where: { $0.trigger != nil }) else {
            removeScreenObserver()
            return
        }
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
            self?.screenParametersChanged()
        }
    }

    private func removeScreenObserver() {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
    }

    private func screenParametersChanged() {
        topologyCheck?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.checkAutomaticRules() }
        topologyCheck = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.topologySettleDelay, execute: work)
    }

    private func checkAutomaticRules() {
        guard running, AppFeature.brightness.isAvailable else { return }
        let current = Self.onlineFingerprints()
        let change = DisplayPresetSupport.changedFingerprints(previous: knownOnlineFingerprints,
                                                              current: current)
        knownOnlineFingerprints = current
        guard !isApplying, Date() >= suppressAutomaticUntil,
              !(change.added.isEmpty && change.removed.isEmpty),
              let preset = DisplayPresetSupport.presetToApply(presets,
                                                              added: change.added,
                                                              removed: change.removed)
        else { return }
        apply(preset)
    }

    // MARK: - Global shortcuts

    private func syncHotkeys() {
        guard running, AppFeature.brightness.isAvailable, !ShortcutCapture.isCapturing else {
            suspendShortcuts()
            return
        }
        var wanted = Set<UUID>()
        for preset in presets {
            guard let raw = preset.shortcut,
                  let shortcut = GlobalShortcut(storageValue: raw) else { continue }
            wanted.insert(preset.id)
            let hotkey: DisplayPresetHotkey
            if let existing = hotkeys[preset.id] {
                hotkey = existing
            } else {
                let id = nextHotkeyID
                nextHotkeyID &+= 1
                hotkey = DisplayPresetHotkey(id: id)
                hotkey.onPress = { [weak self] in self?.apply(id: preset.id) }
                hotkeys[preset.id] = hotkey
            }
            if !hotkey.sync(enabled: true, shortcut: shortcut,
                            storageKey: Self.shortcutStorageKey(preset.id)) {
                Self.log.notice("shortcut for preset \(preset.name, privacy: .public) was refused")
            }
        }
        for (id, hotkey) in hotkeys where !wanted.contains(id) {
            hotkey.unregister()
            hotkeys.removeValue(forKey: id)
        }
    }

    private static func shortcutStorageKey(_ id: UUID) -> String {
        "displayPresetShortcut.\(id.uuidString)"
    }
}

private extension Array where Element == DisplayPreset {
    func with(_ element: DisplayPreset, at index: Int) -> [DisplayPreset] {
        var copy = self
        copy[index] = element
        return copy
    }
}

/// One Carbon global hotkey per preset, sharing one event handler. Mirrors the
/// quick tools' registrar: presses are routed by id, and the ownership
/// registry hears about the key coming and going.
private final class DisplayPresetHotkey {
    private static var instances: [UInt32: DisplayPresetHotkey] = [:]
    private static var sharedHandler: EventHandlerRef?

    private let hotKeyID: UInt32
    private var hotKeyRef: EventHotKeyRef?
    private var registeredShortcut: GlobalShortcut?
    private var claimedKey: String?
    var onPress: (() -> Void)?

    init(id: UInt32) {
        hotKeyID = id
    }

    @discardableResult
    func sync(enabled: Bool, shortcut: GlobalShortcut, storageKey: String) -> Bool {
        guard enabled else {
            unregister()
            return true
        }
        if hotKeyRef != nil, registeredShortcut == shortcut { return true }
        unregister()
        Self.installSharedHandlerIfNeeded()
        Self.instances[hotKeyID] = self
        let id = EventHotKeyID(signature: 0x5655_4450, id: hotKeyID) // 'VUDP'
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.carbonKeyCode,
                                         shortcut.carbonModifiers,
                                         id, GetEventDispatcherTarget(), 0, &ref)
        guard status == noErr, let ref else {
            registeredShortcut = nil
            return false
        }
        hotKeyRef = ref
        registeredShortcut = shortcut
        claimedKey = storageKey
        SystemShortcutTakeover.claim(storageKey, shortcut: shortcut)
        return true
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let claimedKey { SystemShortcutTakeover.release(claimedKey) }
        claimedKey = nil
        hotKeyRef = nil
        registeredShortcut = nil
        Self.instances.removeValue(forKey: hotKeyID)
    }

    private static func installSharedHandlerIfNeeded() {
        guard sharedHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ -> OSStatus in
            var id = EventHotKeyID()
            if let event {
                GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID), nil,
                                  MemoryLayout<EventHotKeyID>.size, nil, &id)
            }
            guard id.signature == 0x5655_4450,
                  let instance = DisplayPresetHotkey.instances[id.id]
            else { return OSStatus(eventNotHandledErr) }
            DispatchQueue.main.async { instance.onPress?() }
            return noErr
        }, 1, &spec, nil, &sharedHandler)
    }
}
