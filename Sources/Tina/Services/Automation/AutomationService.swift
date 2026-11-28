// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices
import Foundation
import IOKit.ps

/// Watches the four supported triggers and runs one existing feature switch
/// per rule. There is no chain, delay, branch or destructive action here:
/// enabling or disabling a feature is the whole vocabulary.
final class AutomationService: ObservableObject {
    static let shared = AutomationService()

    struct RunRecord: Identifiable, Equatable {
        let id = UUID()
        let date: Date
        let ruleName: String
        let detail: String
    }

    @Published private(set) var recentRuns: [RunRecord] = []

    private var rules: [AutomationRule] = []
    private var timer: Timer?
    private var appObserver: NSKeyValueObservation?
    private var runningApps: Set<NSRunningApplication> = []
    private var displayObserver: NSObjectProtocol?
    private var powerSource: CFRunLoopSource?
    private var lastScheduleCheck: Date?
    private var lastOccurrence: [UUID: Date] = [:]
    private var generation = 0
    private var screenCount = 0
    private var wasOnPower = true

    private init() {}

    var isRunning: Bool { !rules.isEmpty }

    func start(rules: [AutomationRule]) {
        stop()
        let configured = AutomationSupport.configuredRules(rules)
        let currentIDs = Set(configured.map(\.id))
        lastOccurrence = lastOccurrence.filter { currentIDs.contains($0.key) }
        self.rules = configured.filter(\.enabled)
        guard !self.rules.isEmpty else { return }
        let current = generation
        if self.rules.contains(where: { if case .app = $0.trigger { return true }; return false }) {
            let workspace = NSWorkspace.shared
            runningApps = Set(workspace.runningApplications)
            // The launch notification omits menu bar and background apps.
            appObserver = workspace.observe(\.runningApplications) { [weak self] workspace, _ in
                let snapshot = workspace.runningApplications
                DispatchQueue.main.async {
                    guard let self, self.generation == current else { return }
                    self.appsChanged(snapshot)
                }
            }
        }
        if self.rules.contains(where: { if case .display = $0.trigger { return true }; return false }) {
            screenCount = NSScreen.screens.count
            displayObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil, queue: .main) { [weak self] _ in
                self?.displayChanged()
            }
        }
        if self.rules.contains(where: { if case .power = $0.trigger { return true }; return false }) {
            wasOnPower = Self.onPower()
            let source = IOPSNotificationCreateRunLoopSource({ context in
                guard let context else { return }
                Unmanaged<AutomationService>.fromOpaque(context).takeUnretainedValue().powerChanged()
            }, Unmanaged.passUnretained(self).toOpaque())
            if let source = source?.takeRetainedValue() {
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
                powerSource = source
            }
        }
        if self.rules.contains(where: { if case .schedule = $0.trigger { return true }; return false }) {
            let now = Date()
            lastScheduleCheck = Calendar.current.dateInterval(of: .minute, for: now)?.start
                .addingTimeInterval(-1) ?? now
            let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
                self?.checkSchedule()
            }
            timer.tolerance = 5
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }

    func stop() {
        generation += 1
        timer?.invalidate()
        timer = nil
        lastScheduleCheck = nil
        appObserver?.invalidate()
        appObserver = nil
        runningApps = []
        if let displayObserver {
            NotificationCenter.default.removeObserver(displayObserver)
        }
        displayObserver = nil
        if let powerSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .commonModes)
        }
        powerSource = nil
        rules = []
    }

    // MARK: - Triggers

    private func checkSchedule() {
        let now = Date()
        guard let previous = lastScheduleCheck else { return }
        lastScheduleCheck = now
        let due = rules.enumerated().compactMap { index, rule -> (Date, Int, AutomationRule)? in
            guard let minute = AutomationSupport.dueMinute(rule.trigger, after: previous, through: now),
                  lastOccurrence[rule.id].map({ $0 < minute }) ?? true else { return nil }
            return (minute, index, rule)
        }.sorted { ($0.0, $0.1) < ($1.0, $1.1) }
        for (minute, _, rule) in due {
            lastOccurrence[rule.id] = minute
            execute(rule)
        }
    }

    private func appsChanged(_ apps: [NSRunningApplication]) {
        let next = Set(apps)
        let launched = next.subtracting(runningApps)
        runningApps = next
        for app in apps where launched.contains(app) {
            if let id = app.bundleIdentifier { evaluate(.app(bundleID: id)) }
        }
    }

    private func powerChanged() {
        let connected = Self.onPower()
        guard connected != wasOnPower else { return }
        wasOnPower = connected
        evaluate(.power(connected: connected))
    }

    private func displayChanged() {
        let count = NSScreen.screens.count
        guard count != screenCount else { return }
        let connected = count > screenCount
        screenCount = count
        evaluate(.display(connected: connected))
    }

    private func evaluate(_ trigger: AutomationTrigger) {
        for rule in rules where rule.enabled && rule.trigger == trigger {
            execute(rule)
        }
    }

    // MARK: - Actions

    private func execute(_ rule: AutomationRule) {
        let defaults = UserDefaults.standard
        guard case .feature(let id, let enabled) = rule.action,
              let feature = AppFeature(rawValue: id),
              feature.isAvailable,
              let key = AutomationSupport.featureSwitches[feature],
              AutomationSupport.canApply(
                feature, notchActive: AppFeature.notch.isAvailable && defaults.bool(forKey: DefaultsKey.notchEnabled),
                accessibility: AXIsProcessTrusted()
              ) else { return }
        guard defaults.bool(forKey: key) != enabled else { return }
        defaults.set(enabled, forKey: key)
        guard defaults.bool(forKey: key) == enabled else { return }
        FeatureRuntime.shared.sync([feature])
        let detail = "\(feature.rawValue) = \(enabled ? "on" : "off")"
        let record = RunRecord(date: Date(),
                               ruleName: rule.name.isEmpty ? rule.trigger.triggerDescription : rule.name,
                               detail: detail)
        recentRuns.insert(record, at: 0)
        if recentRuns.count > 20 { recentRuns.removeLast(recentRuns.count - 20) }
    }

    private static func onPower() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue()
        else { return true }
        return type as String == kIOPMACPowerKey
    }
}

extension AutomationTrigger {
    var triggerDescription: String {
        switch self {
        case .schedule(let hour, let minute, _):
            return String(format: "%02d:%02d", hour, minute)
        case .power(let connected): return connected ? "Power connected" : "Power disconnected"
        case .display(let connected): return connected ? "Display connected" : "Display disconnected"
        case .app(let bundleID): return bundleID
        }
    }
}
