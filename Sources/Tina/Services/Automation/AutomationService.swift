// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
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
    private var observers: [NSObjectProtocol] = []
    private var displayObserver: NSObjectProtocol?
    private var powerSource: CFRunLoopSource?
    private var lastMinuteSignature = ""
    private var screenCount = NSScreen.screens.count
    private var wasOnPower = true

    private init() {}

    var isRunning: Bool { timer != nil }

    func start(rules: [AutomationRule]) {
        stop()
        self.rules = AutomationSupport.sanitized(
            rules,
            knownFeatures: Set(AppFeature.allCases.map(\.rawValue)),
            knownToggles: Set<String>())
        guard !self.rules.isEmpty else { return }
        screenCount = NSScreen.screens.count
        wasOnPower = Self.onPower()
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification,
                                            object: nil, queue: .main) { [weak self] note in
            guard let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication)?.bundleIdentifier else { return }
            self?.evaluate(.app(bundleID: bundleID))
        })
        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
            self?.displayChanged()
        }
        let powerSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let service = Unmanaged<AutomationService>.fromOpaque(context)
                .takeUnretainedValue()
            DispatchQueue.main.async { service.powerChanged() }
        }, Unmanaged.passUnretained(self).toOpaque())
        if let source = powerSource?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            self.powerSource = source
        }
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkSchedule()
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
        observers = []
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
        let signature = ISO8601DateFormatter().string(from: now).prefix(16).description
        guard signature != lastMinuteSignature else { return }
        lastMinuteSignature = signature
        for rule in rules where rule.enabled {
            if AutomationSupport.scheduleMatches(rule.trigger, at: now) {
                execute(rule)
            }
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
        guard case .feature(let id, let enabled) = rule.action,
              let feature = AppFeature(rawValue: id),
              feature.isAvailable else { return }
        for key in feature.enabledKeys {
            UserDefaults.standard.set(enabled, forKey: key)
        }
        FeatureRuntime.shared.sync([feature])
        let detail = "\(feature.rawValue) \(enabled ? "on" : "off")"
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
