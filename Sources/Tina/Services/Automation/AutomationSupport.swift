// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// One trigger and one action. The first version deliberately has no chains,
/// delays, branches or variables: a rule either fires an existing feature
/// switch or a quick toggle, or it does nothing.
enum AutomationTrigger: Codable, Equatable {
    /// A wall-clock time on the chosen weekdays (1 = Sunday ... 7 = Saturday).
    case schedule(hour: Int, minute: Int, weekdays: [Int])
    /// The power adapter connected or disconnected.
    case power(connected: Bool)
    /// A display was connected or disconnected.
    case display(connected: Bool)
    /// An app launched.
    case app(bundleID: String)
}

enum AutomationAction: Codable, Equatable {
    /// Turn an installed feature on or off, by its stable raw value.
    case feature(id: String, enabled: Bool)
    /// Run one quick toggle, by its stable raw value.
    case quickToggle(id: String)
}

struct AutomationRule: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String = ""
    var enabled: Bool = true
    var trigger: AutomationTrigger
    var action: AutomationAction
}

enum AutomationSupport {
    static let maximumRules = 32

    /// Drops rules with an unusable trigger or an unknown feature id, keeps
    /// the first rule for an identical trigger + action pair, and caps the
    /// list.
    static func sanitized(_ rules: [AutomationRule],
                          knownFeatures: Set<String>,
                          knownToggles: Set<String>) -> [AutomationRule] {
        var seen: Set<String> = []
        var result: [AutomationRule] = []
        for rule in rules {
            guard isValid(rule, knownFeatures: knownFeatures, knownToggles: knownToggles)
            else { continue }
            let key = signature(rule)
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(rule)
            if result.count >= maximumRules { break }
        }
        return result
    }

    static func isValid(_ rule: AutomationRule,
                        knownFeatures: Set<String>,
                        knownToggles: Set<String>) -> Bool {
        switch rule.action {
        case .feature(let id, _):
            guard knownFeatures.contains(id) else { return false }
        case .quickToggle(let id):
            guard knownToggles.contains(id) else { return false }
        }
        switch rule.trigger {
        case .schedule(let hour, let minute, let weekdays):
            guard (0...23).contains(hour), (0...59).contains(minute),
                  !weekdays.isEmpty,
                  weekdays.allSatisfy({ (1...7).contains($0) }) else { return false }
        case .app(let bundleID):
            guard !bundleID.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        case .power, .display:
            break
        }
        return true
    }

    /// Whether the schedule trigger fires at this minute. Matching is exact on
    /// hour and minute, so a per-minute timer calls this once.
    static func scheduleMatches(_ trigger: AutomationTrigger,
                                at date: Date,
                                calendar: Calendar = .current) -> Bool {
        guard case .schedule(let hour, let minute, let weekdays) = trigger else { return false }
        let parts = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        guard let currentHour = parts.hour,
              let currentMinute = parts.minute,
              let weekday = parts.weekday
        else { return false }
        return currentHour == hour && currentMinute == minute && weekdays.contains(weekday)
    }

    static func signature(_ rule: AutomationRule) -> String {
        let trigger: String
        switch rule.trigger {
        case .schedule(let hour, let minute, let weekdays):
            trigger = "time:\(hour):\(minute):\(weekdays.sorted())"
        case .power(let connected):
            trigger = "power:\(connected)"
        case .display(let connected):
            trigger = "display:\(connected)"
        case .app(let bundleID):
            trigger = "app:\(bundleID)"
        }
        let action: String
        switch rule.action {
        case .feature(let id, let enabled):
            action = "feature:\(id):\(enabled)"
        case .quickToggle(let id):
            action = "toggle:\(id)"
        }
        return trigger + "|" + action
    }

    static func feature(for action: AutomationAction) -> AppFeature? {
        guard case .feature(let id, _) = action else { return nil }
        return AppFeature(rawValue: id)
    }
}
