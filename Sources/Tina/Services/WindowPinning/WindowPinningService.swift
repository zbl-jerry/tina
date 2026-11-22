// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import SwiftUI

/// A pinned window as the surfaces list it.
struct WindowPinSummary: Identifiable, Equatable {
    let id: CGWindowID
    let title: String
    let appName: String
    let isPaused: Bool
}

/// Owns every live window mirror. One controller exists per pinned window; a
/// single poll watches the WindowServer for movement, closure, occlusion and
/// Space changes, so no AX observers or per-window timers are needed.
///
/// The service is inert unless the feature is installed, switched on, and
/// Screen Recording is granted. Uninstalling or switching it off tears every
/// stream and panel down on the spot.
final class WindowPinningService: ObservableObject {
    static let shared = WindowPinningService()

    @Published private(set) var pins: [WindowPinSummary] = []
    @Published private(set) var isPickerOpen = false

    private var controllers: [CGWindowID: PinnedWindowController] = [:]
    private var pollTimer: Timer?
    private var pickerPanel: NSPanel?
    private let pickerModel = WindowPinPickerModel()

    private init() {}

    private var isEngaged: Bool {
        AppFeature.windowPinning.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.windowPinningEnabled)
            && Permissions.shared.screenRecording
    }

    var frameRate: Int {
        WindowPinningSupport.sanitizedFrameRate(
            UserDefaults.standard.integer(forKey: DefaultsKey.windowPinningFrameRate))
    }

    var handoff: WindowPinHandoff {
        WindowPinHandoff.sanitized(
            UserDefaults.standard.string(forKey: DefaultsKey.windowPinningHandoff))
    }

    var keepsKeyboardFocus: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKey.windowPinningKeepFocus)
    }

    var pausesWhenHidden: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKey.windowPinningPauseWhenHidden)
    }

    // MARK: Lifecycle

    /// Features call this whenever availability, the switch or Screen
    /// Recording changes. Off means nothing runs and every mirror disappears.
    func syncWithPreferences() {
        guard isEngaged else {
            closeAll()
            stopPolling()
            hidePicker()
            return
        }
        startPolling()
        for controller in controllers.values {
            controller.applyPreferences()
        }
        refreshPickerIfOpen()
    }

    private func startPolling() {
        guard pollTimer == nil else { return }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 0.15
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        tick()
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func tick() {
        guard isEngaged else {
            closeAll()
            stopPolling()
            return
        }
        let snapshot = WindowServerSnapshot.capture()
        for controller in controllers.values {
            controller.update(snapshot: snapshot)
        }
        refreshPickerIfOpen()
    }

    // MARK: Pins

    /// Every normal application window currently on screen, in front-to-back
    /// order. Empty without Screen Recording: the WindowServer hides titles
    /// and content of other apps from an untrusted process, so offering a list
    /// there would only produce windows that cannot be mirrored.
    func candidates() -> [WindowPinCandidate] {
        guard Permissions.shared.screenRecording else { return [] }
        let snapshot = WindowServerSnapshot.capture()
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return snapshot.orderedOnScreen.compactMap { entry -> WindowPinCandidate? in
            guard WindowPinningSupport.isPinnable(
                pid: entry.pid, layer: entry.layer, alpha: entry.alpha,
                frame: entry.frame, ownerName: snapshot.ownerName(for: entry),
                ownPID: ownPID, activationPolicy: snapshot.activationPolicy(for: entry))
            else { return nil }
            return WindowPinCandidate(windowID: entry.windowID,
                                      pid: entry.pid,
                                      appName: snapshot.appName(for: entry),
                                      title: snapshot.windowTitle(for: entry),
                                      bundleIdentifier: snapshot.bundleIdentifier(for: entry),
                                      frame: entry.frame)
        }
    }

    func pin(_ candidate: WindowPinCandidate) {
        guard AppFeature.windowPinning.isAvailable,
              Permissions.shared.screenRecording,
              controllers[candidate.windowID] == nil else { return }
        // Pinning is an explicit use of the feature: the first pin turns the
        // switch on, so the picker never appears to accept a pin and do
        // nothing. The Hub still owns whether the feature exists at all.
        if !UserDefaults.standard.bool(forKey: DefaultsKey.windowPinningEnabled) {
            UserDefaults.standard.set(true, forKey: DefaultsKey.windowPinningEnabled)
        }
        guard isEngaged else { return }
        startPolling()
        let controller = PinnedWindowController(candidate: candidate, service: self)
        controllers[candidate.windowID] = controller
        controller.start(cascadeIndex: controllers.count - 1)
        publishPins()
    }

    func unpin(_ windowID: CGWindowID) {
        guard let controller = controllers.removeValue(forKey: windowID) else { return }
        controller.stop()
        publishPins()
    }

    func unpinAll() {
        closeAll()
    }

    func togglePause(_ windowID: CGWindowID) {
        controllers[windowID]?.toggleUserPause()
        publishPins()
    }

    func handOff(_ windowID: CGWindowID) {
        controllers[windowID]?.handOff()
    }

    func closeAll() {
        let existing = controllers.values
        controllers.removeAll()
        for controller in existing {
            controller.stop()
        }
        publishPins()
    }

    func notifyPinChanged() {
        publishPins()
    }

    private func publishPins() {
        let next = controllers.values
            .map { WindowPinSummary(id: $0.windowID, title: $0.title,
                                    appName: $0.appName, isPaused: $0.isSummaryPaused) }
            .sorted { $0.id < $1.id }
        guard next != pins else { return }
        pins = next
    }

    // MARK: Picker

    func showPicker() {
        guard AppFeature.windowPinning.isAvailable else { return }
        if pickerPanel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 440),
                                styleMask: [.titled, .closable, .resizable],
                                backing: .buffered, defer: false)
            panel.title = FeatureStrings.windowPinning(L10n.shared.language).pickerTitle
            panel.isReleasedWhenClosed = false
            panel.minSize = NSSize(width: 380, height: 320)
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: WindowPinPickerView(
                model: pickerModel,
                strings: FeatureStrings.windowPinning(L10n.shared.language),
                onClose: { [weak self] in self?.hidePicker() }))
            panel.center()
            pickerPanel = panel
        }
        pickerModel.attach(self)
        pickerModel.refresh()
        pickerPanel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isPickerOpen = true
    }

    func hidePicker() {
        pickerPanel?.orderOut(nil)
        isPickerOpen = false
    }

    private func refreshPickerIfOpen() {
        guard isPickerOpen else { return }
        pickerModel.refresh()
    }

    func candidateClosed(_ windowID: CGWindowID) {
        unpin(windowID)
    }
}

/// One reading of the WindowServer, shared by every mirror in a poll.
struct WindowServerSnapshot {
    let orderedOnScreen: [WindowServerWindowEntry]
    let allByID: [CGWindowID: WindowServerWindowEntry]
    private let ownerNames: [pid_t: String]
    private let appNames: [pid_t: String]
    private let windowTitles: [CGWindowID: String]
    private let bundleIdentifiers: [pid_t: String]
    private let activationPolicies: [pid_t: NSApplication.ActivationPolicy]

    func ownerName(for entry: WindowServerWindowEntry) -> String {
        ownerNames[entry.pid] ?? ""
    }

    func windowTitle(for entry: WindowServerWindowEntry) -> String {
        windowTitles[entry.windowID] ?? ""
    }

    func appName(for entry: WindowServerWindowEntry) -> String {
        appNames[entry.pid] ?? ownerNames[entry.pid] ?? ""
    }

    func bundleIdentifier(for entry: WindowServerWindowEntry) -> String? {
        bundleIdentifiers[entry.pid]
    }

    func activationPolicy(for entry: WindowServerWindowEntry) -> NSApplication.ActivationPolicy? {
        activationPolicies[entry.pid]
    }

    static func capture() -> WindowServerSnapshot {
        let onScreen = read([.optionOnScreenOnly, .excludeDesktopElements])
        let all = read([.optionAll, .excludeDesktopElements])
        var ownerNames: [pid_t: String] = [:]
        var appNames: [pid_t: String] = [:]
        var bundleIdentifiers: [pid_t: String] = [:]
        var activationPolicies: [pid_t: NSApplication.ActivationPolicy] = [:]
        for entry in onScreen.entries where appNames[entry.pid] == nil {
            let app = NSRunningApplication(processIdentifier: entry.pid)
            ownerNames[entry.pid] = onScreen.ownerNames[entry.windowID] ?? ""
            appNames[entry.pid] = app?.localizedName ?? ownerNames[entry.pid]
            if let bundleIdentifier = app?.bundleIdentifier {
                bundleIdentifiers[entry.pid] = bundleIdentifier
            }
            if let policy = app?.activationPolicy {
                activationPolicies[entry.pid] = policy
            }
        }
        return WindowServerSnapshot(orderedOnScreen: onScreen.entries,
                                    allByID: all.byID,
                                    ownerNames: ownerNames,
                                    appNames: appNames,
                                    windowTitles: onScreen.titles,
                                    bundleIdentifiers: bundleIdentifiers,
                                    activationPolicies: activationPolicies)
    }

    private struct Reading {
        var entries: [WindowServerWindowEntry] = []
        var byID: [CGWindowID: WindowServerWindowEntry] = [:]
        var ownerNames: [CGWindowID: String] = [:]
        var titles: [CGWindowID: String] = [:]
    }

    private static func read(_ options: CGWindowListOption) -> Reading {
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
        else { return Reading() }
        var reading = Reading()
        for info in raw {
            guard let number = info[kCGWindowNumber as String] as? NSNumber,
                  let pid = info[kCGWindowOwnerPID as String] as? NSNumber,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary)
            else { continue }
            let entry = WindowServerWindowEntry(
                windowID: number.uint32Value,
                pid: pid.int32Value,
                layer: (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0,
                alpha: (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1,
                isOnScreen: (info[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false,
                frame: frame)
            reading.entries.append(entry)
            reading.byID[entry.windowID] = entry
            if let owner = info[kCGWindowOwnerName as String] as? String {
                reading.ownerNames[entry.windowID] = owner
            }
            if let title = info[kCGWindowName as String] as? String {
                reading.titles[entry.windowID] = title
            }
        }
        return reading
    }
}

/// The picker's live list. It refreshes on the service's poll while the panel
/// is open, so a window that closes simply leaves the list.
final class WindowPinPickerModel: ObservableObject {
    @Published private(set) var candidates: [WindowPinCandidate] = []
    @Published var query = ""
    @Published private(set) var pinnedIDs: Set<CGWindowID> = []

    private weak var service: WindowPinningService?

    func attach(_ service: WindowPinningService) {
        self.service = service
    }

    func refresh() {
        let service = service ?? WindowPinningService.shared
        let next = service.candidates()
        if next != candidates { candidates = next }
        let pinned = Set(service.pins.map(\.id))
        if pinned != pinnedIDs { pinnedIDs = pinned }
    }

    var filtered: [WindowPinCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return candidates }
        return candidates.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(trimmed)
                || $0.appName.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func pin(_ candidate: WindowPinCandidate) {
        service?.pin(candidate)
        refresh()
    }
}
