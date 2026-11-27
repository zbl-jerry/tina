// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreGraphics
import Foundation

/// Collects the aggregates the usage page shows. Only counts and elapsed time
/// are read: key codes, typed text, window titles and paths are never touched.
///
/// The service is passive and opt-in. It samples every 30 seconds, adds the
/// elapsed time to the frontmost app and to screen-on time, and counts key
/// presses (autorepeat excluded) and mouse clicks through global monitors.
/// Without Accessibility the monitors simply deliver nothing; App and screen
/// time still work.
final class UsageStatsService {
    static let shared = UsageStatsService()

    private let store: UsageStatsStore
    private var timer: Timer?
    private var activationObserver: NSObjectProtocol?
    private var keyMonitor: Any?
    private var clickMonitor: Any?
    private var lastTick = Date()
    private var frontmostBundleID: String?
    private var pendingKeys = 0
    private var pendingClicks = 0

    init(store: UsageStatsStore = .shared) {
        self.store = store
    }

    var isRunning: Bool { timer != nil }

    func start() {
        guard timer == nil else { return }
        lastTick = Date()
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.frontmostBundleID = app?.bundleIdentifier
        }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard !event.isARepeat else { return }
            self?.pendingKeys += 1
        }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.pendingClicks += 1
        }
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.sample()
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        store.flush()
        timer?.invalidate()
        timer = nil
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        activationObserver = nil
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        keyMonitor = nil
        clickMonitor = nil
        pendingKeys = 0
        pendingClicks = 0
    }

    /// One sample. Public so tests and the page can force a final flush.
    func sample(now: Date = Date()) {
        let elapsed = max(0, now.timeIntervalSince(lastTick))
        lastTick = now
        guard elapsed > 0 else { return }
        let screenOn = CGDisplayIsAsleep(CGMainDisplayID()) == 0
        let keys = pendingKeys
        let clicks = pendingClicks
        pendingKeys = 0
        pendingClicks = 0
        store.add(appBundleID: frontmostBundleID,
                  seconds: screenOn ? elapsed : 0,
                  screenOn: screenOn,
                  keyPresses: keys,
                  clicks: clicks,
                  now: now)
    }
}
