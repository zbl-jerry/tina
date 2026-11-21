// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import CoreGraphics

/// The per-app smooth scrolling table, kept ready for both wheel taps.
///
/// The lists are written on the main thread; the taps that ask run on the main
/// run loop (smooth scrolling) and the pointer thread (the scroll inverter), so
/// both tables are guarded by `lock` and a callback never resolves anything
/// itself. The `pid → override` table is rebuilt from the running applications,
/// which is enough for the app that owns the window the wheel is over; a
/// missing entry while the main thread is available is resolved once and
/// remembered.
final class ScrollPerAppOverrides: ObservableObject {
    static let shared = ScrollPerAppOverrides()

    @Published private(set) var overrides: [ScrollPerAppOverride] = []

    private let lock = NSLock()
    private var byBundleID: [String: ScrollPerAppOverride] = [:]
    private var byProcessID: [Int32: ScrollPerAppOverride] = [:]
    /// Process ids checked while the main thread was available and found not
    /// to be in the table. Without this every wheel tick over an unlisted app
    /// would ask the workspace again.
    private var unresolvedProcessIDs: Set<Int32> = []
    private var runningApplicationsObservation: NSKeyValueObservation?

    private init() {
        reload()
    }

    // MARK: - Reading

    func list() -> [ScrollPerAppOverride] { overrides }

    /// The record that names this app, if any. Reading is a single dictionary
    /// lookup so the pointer thread never waits for the main one.
    func override(forProcessID processID: Int32) -> ScrollPerAppOverride? {
        guard processID > 0, AppFeature.smoothScroll.isAvailable else { return nil }
        return lock.withLock { byProcessID[processID] }
    }

    /// Same answer, with one main-thread lookup for an app the workspace
    /// observation has not seen yet. Only for callbacks that run on the main
    /// thread, such as smooth scrolling's tap.
    func override(forProcessID processID: Int32, resolvingMissing: Bool) -> ScrollPerAppOverride? {
        if let found = override(forProcessID: processID) { return found }
        guard resolvingMissing, Thread.isMainThread,
              AppFeature.smoothScroll.isAvailable else { return nil }
        let (table, knownMissing) = lock.withLock { (byBundleID, unresolvedProcessIDs.contains(processID)) }
        guard !table.isEmpty, !knownMissing else { return nil }
        guard let app = NSRunningApplication(processIdentifier: processID),
              let bundleID = app.bundleIdentifier,
              let found = table[bundleID] else {
            lock.withLock { _ = unresolvedProcessIDs.insert(processID) }
            return nil
        }
        lock.withLock { byProcessID[processID] = found }
        return found
    }

    // MARK: - The table

    /// Applies the persisted table; safe to call repeatedly.
    func reload() {
        let raw = UserDefaults.standard.string(forKey: DefaultsKey.scrollPerAppOverrides) ?? ""
        apply(ScrollPerAppSupport.decode(raw))
    }

    func add(_ bundleID: String) {
        guard !overrides.contains(where: { $0.bundleID == bundleID }) else { return }
        var updated = overrides
        updated.append(ScrollPerAppOverride(bundleID: bundleID, smoothing: .off))
        persist(updated)
    }

    func remove(_ bundleID: String) {
        guard overrides.contains(where: { $0.bundleID == bundleID }) else { return }
        persist(overrides.filter { $0.bundleID != bundleID })
    }

    /// The stored step and speed are kept while the app is not custom, so
    /// switching modes back and forth does not lose the hand-tuned values.
    func setSmoothing(_ smoothing: ScrollPerAppSmoothing, for bundleID: String) {
        update(bundleID) { item in
            item.smoothing = smoothing
        }
    }

    func setStep(_ step: Int?, for bundleID: String) {
        update(bundleID) { item in
            item.step = ScrollPerAppSupport.sanitizedStep(step)
        }
    }

    func setSpeedPercent(_ percent: Int, for bundleID: String) {
        update(bundleID) { item in
            item.speedPercent = ScrollPerAppSupport.sanitizedSpeedPercent(percent)
        }
    }

    /// nil follows the global vertical inversion; true or false overrides it
    /// for this app alone.
    func setInvertVertical(_ invert: Bool?, for bundleID: String) {
        update(bundleID) { item in
            item.invertVertical = invert
        }
    }

    private func update(_ bundleID: String, _ change: (inout ScrollPerAppOverride) -> Void) {
        guard let index = overrides.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        var updated = overrides
        change(&updated[index])
        persist(updated)
    }

    private func persist(_ updated: [ScrollPerAppOverride]) {
        let sanitized = ScrollPerAppSupport.sanitized(updated)
        UserDefaults.standard.set(ScrollPerAppSupport.encode(sanitized),
                                  forKey: DefaultsKey.scrollPerAppOverrides)
        apply(sanitized)
    }

    private func apply(_ table: [ScrollPerAppOverride]) {
        overrides = table
        lock.withLock {
            byBundleID = Dictionary(table.map { ($0.bundleID, $0) },
                                    uniquingKeysWith: { _, latest in latest })
        }
        // The table is read by the pointer thread too, so it is updated in
        // place above. The workspace observer and process map are main-thread
        // work and wait for it when the first lookup came from a tap.
        let refresh = { [weak self] in
            guard let self else { return }
            self.refreshObservation()
            self.rebuildProcessMap(NSWorkspace.shared.runningApplications)
        }
        if Thread.isMainThread {
            refresh()
        } else {
            DispatchQueue.main.async(execute: refresh)
        }
    }

    // MARK: - Resolving the receiving app

    /// With every table empty, which is the normal case, no observer or process
    /// map is kept alive.
    private func refreshObservation() {
        let needed = lock.withLock { !byBundleID.isEmpty }
        if needed {
            guard runningApplicationsObservation == nil else { return }
            runningApplicationsObservation = NSWorkspace.shared.observe(
                \.runningApplications, options: [.initial, .new]) { [weak self] workspace, _ in
                    self?.rebuildProcessMap(workspace.runningApplications)
                }
        } else {
            runningApplicationsObservation?.invalidate()
            runningApplicationsObservation = nil
            lock.withLock { byProcessID.removeAll(keepingCapacity: false) }
        }
    }

    private func rebuildProcessMap(_ applications: [NSRunningApplication]) {
        let table = lock.withLock { byBundleID }
        guard !table.isEmpty else {
            lock.withLock {
                byProcessID.removeAll(keepingCapacity: false)
                unresolvedProcessIDs.removeAll(keepingCapacity: false)
            }
            return
        }
        var rebuilt: [Int32: ScrollPerAppOverride] = [:]
        for app in applications {
            guard let bundleID = app.bundleIdentifier, let item = table[bundleID] else { continue }
            rebuilt[app.processIdentifier] = item
        }
        lock.withLock {
            byProcessID = rebuilt
            // A launch or a quit can change what a process id answers to.
            unresolvedProcessIDs.removeAll(keepingCapacity: false)
        }
    }
}
