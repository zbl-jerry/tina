// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreGraphics
import Foundation

/// A sample settles the state that held before the boundary, not its new state.
/// Wall time names the day; monotonic uptime measures elapsed seconds.
struct UsageStatsTimeline {
    struct Portion: Equatable {
        let day: Date
        let bundleID: String?
        let seconds: TimeInterval
    }

    private var date: Date
    private var uptime: TimeInterval
    var bundleID: String?
    var systemAwake = true
    var screenAwake: Bool

    init(date: Date, uptime: TimeInterval, bundleID: String?, screenAwake: Bool) {
        self.date = date
        self.uptime = uptime
        self.bundleID = bundleID
        self.screenAwake = screenAwake
    }

    mutating func settle(at now: Date, uptime currentUptime: TimeInterval,
                         calendar: Calendar) -> [Portion] {
        let elapsed = currentUptime - uptime
        let wallElapsed = now.timeIntervalSince(date)
        let previousDate = date
        date = now
        uptime = currentUptime
        guard systemAwake, screenAwake, elapsed.isFinite, elapsed > 0 else { return [] }
        // If the clock jumped, place the measured time relative to the current
        // wall clock rather than billing the discontinuity as time spent.
        let start = abs(wallElapsed - elapsed) <= 1 ? previousDate : now.addingTimeInterval(-elapsed)

        var cursor = start
        let end = start.addingTimeInterval(elapsed)
        var result: [Portion] = []
        while cursor < end, let day = calendar.dateInterval(of: .day, for: cursor) {
            let boundary = min(end, day.end)
            guard boundary > cursor else { break }
            result.append(Portion(day: day.start, bundleID: bundleID,
                                  seconds: boundary.timeIntervalSince(cursor)))
            cursor = boundary
        }
        return result
    }
}

/// Collects only aggregate counts and times. Never reads key codes, text,
/// titles or paths. Global and local monitors cover distinct event streams.
final class UsageStatsService {
    static let shared = UsageStatsService()

    private struct InputCounts {
        var keys = 0
        var clicks = 0
    }

    private let store: UsageStatsStore
    private let calendar = Calendar.current
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var monitors: [Any] = []
    private var timeline: UsageStatsTimeline?
    private var pendingInput: [Date: InputCounts] = [:]

    init(store: UsageStatsStore = .shared) {
        self.store = store
    }

    var isRunning: Bool { timeline != nil }

    func start() {
        guard !isRunning else { return }
        let workspace = NSWorkspace.shared
        timeline = UsageStatsTimeline(date: Date(), uptime: ProcessInfo.processInfo.systemUptime,
                                      bundleID: workspace.frontmostApplication?.bundleIdentifier,
                                      screenAwake: Self.mainScreenIsAwake)
        let center = workspace.notificationCenter
        func observe(_ name: Notification.Name, _ action: @escaping (UsageStatsService, Notification) -> Void) {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let self, self.isRunning else { return }
                self.sample()
                action(self, note)
            })
        }
        observe(NSWorkspace.didActivateApplicationNotification) { service, note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            service.timeline?.bundleID = app?.bundleIdentifier
        }
        observe(NSWorkspace.willSleepNotification) { service, _ in
            service.timeline?.systemAwake = false
        }
        observe(NSWorkspace.didWakeNotification) { service, _ in
            service.timeline?.systemAwake = true
            service.timeline?.screenAwake = Self.mainScreenIsAwake
        }
        observe(NSWorkspace.screensDidSleepNotification) { service, _ in
            service.timeline?.screenAwake = false
        }
        observe(NSWorkspace.screensDidWakeNotification) { service, _ in
            service.timeline?.screenAwake = true
        }

        let mask: NSEvent.EventTypeMask = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.recordInput(event)
        }) { monitors.append(monitor) }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.recordInput(event)
            return event
        }) { monitors.append(monitor) }

        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in self?.sample() }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        guard isRunning else { return }
        timer?.invalidate()
        timer = nil
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers = []
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        sample()
        timeline = nil
        store.flush()
    }

    func clear() {
        sample()
        store.clear()
    }

    private func recordInput(_ event: NSEvent) {
        guard isRunning else { return }
        let day = calendar.startOfDay(for: Date())
        if event.type == .keyDown {
            guard !event.isARepeat else { return }
            pendingInput[day, default: InputCounts()].keys += 1
        } else {
            pendingInput[day, default: InputCounts()].clicks += 1
        }
    }

    private func sample() {
        let now = Date()
        guard let portions = timeline?.settle(at: now, uptime: ProcessInfo.processInfo.systemUptime,
                                               calendar: calendar) else { return }
        var input = pendingInput
        pendingInput = [:]
        for portion in portions {
            let counts = input.removeValue(forKey: portion.day)
            store.add(appBundleID: portion.bundleID, seconds: portion.seconds, screenOn: true,
                      keyPresses: counts?.keys ?? 0, clicks: counts?.clicks ?? 0, now: portion.day,
                      observedAt: now)
        }
        for (day, counts) in input.sorted(by: { $0.key < $1.key }) {
            store.add(appBundleID: nil, seconds: 0, screenOn: false,
                      keyPresses: counts.keys, clicks: counts.clicks, now: day, observedAt: now)
        }
    }

    private static var mainScreenIsAwake: Bool {
        CGDisplayIsAsleep(CGMainDisplayID()) == 0
    }
}
