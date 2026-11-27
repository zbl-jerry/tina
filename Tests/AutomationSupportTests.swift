// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

enum AutomationSupportTests {
    static func run(_ suite: TestSuite) {
        let features: Set<String> = ["nightWarmth", "keepAwake"]
        let toggles: Set<String> = ["darkMode", "emptyTrash"]

        func rule(_ trigger: AutomationTrigger,
                  _ action: AutomationAction,
                  enabled: Bool = true) -> AutomationRule {
            AutomationRule(enabled: enabled, trigger: trigger, action: action)
        }

        // Validation.
        suite.expect(AutomationSupport.isValid(
            rule(.schedule(hour: 22, minute: 30, weekdays: [1, 2, 3, 4, 5]),
                 .feature(id: "nightWarmth", enabled: true)),
            knownFeatures: features, knownToggles: toggles),
            "a complete schedule rule is valid")
        suite.expect(!AutomationSupport.isValid(
            rule(.schedule(hour: 24, minute: 0, weekdays: [1]),
                 .feature(id: "nightWarmth", enabled: true)),
            knownFeatures: features, knownToggles: toggles),
            "an impossible hour is rejected")
        suite.expect(!AutomationSupport.isValid(
            rule(.schedule(hour: 22, minute: 30, weekdays: []),
                 .feature(id: "nightWarmth", enabled: true)),
            knownFeatures: features, knownToggles: toggles),
            "a schedule without weekdays never fires and is rejected")
        suite.expect(!AutomationSupport.isValid(
            rule(.power(connected: true), .feature(id: "unknown", enabled: true)),
            knownFeatures: features, knownToggles: toggles),
            "an unknown feature id is rejected")
        suite.expect(!AutomationSupport.isValid(
            rule(.power(connected: true), .quickToggle(id: "unknown")),
            knownFeatures: features, knownToggles: toggles),
            "an unknown toggle id is rejected")
        suite.expect(AutomationSupport.isValid(
            rule(.app(bundleID: "com.apple.dt.Xcode"),
                 .quickToggle(id: "darkMode")),
            knownFeatures: features, knownToggles: toggles),
            "an app trigger with a toggle action is valid")

        // Deduplication keeps the first rule for a trigger+action pair.
        let a = rule(.power(connected: true), .feature(id: "nightWarmth", enabled: false))
        let b = rule(.power(connected: true), .feature(id: "nightWarmth", enabled: false))
        let cleaned = AutomationSupport.sanitized([a, b],
                                                  knownFeatures: features,
                                                  knownToggles: toggles)
        suite.expect(cleaned.count == 1, "an identical rule is not stored twice")

        // The cap keeps the list bounded.
        let many = (0..<(AutomationSupport.maximumRules + 5)).map { index in
            rule(.app(bundleID: "com.app.\(index)"), .quickToggle(id: "darkMode"))
        }
        suite.expect(AutomationSupport.sanitized(many,
                                                 knownFeatures: features,
                                                 knownToggles: toggles).count
                     == AutomationSupport.maximumRules,
                     "the rule list is capped")

        // Schedule matching: exact hour and minute, weekday included.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = Date(timeIntervalSince1970: 1_764_000_000)
        let parts = calendar.dateComponents([.hour, .minute, .weekday], from: monday)
        let matching = AutomationTrigger.schedule(hour: parts.hour!,
                                                  minute: parts.minute!,
                                                  weekdays: [parts.weekday!])
        suite.expect(AutomationSupport.scheduleMatches(matching, at: monday, calendar: calendar),
                     "the matching minute fires")
        let wrongMinute = AutomationTrigger.schedule(hour: parts.hour!,
                                                     minute: (parts.minute! + 1) % 60,
                                                     weekdays: [parts.weekday!])
        suite.expect(!AutomationSupport.scheduleMatches(wrongMinute, at: monday, calendar: calendar),
                     "a different minute does not fire")
        let wrongDay = AutomationTrigger.schedule(hour: parts.hour!,
                                                  minute: parts.minute!,
                                                  weekdays: [(parts.weekday! % 7) + 1])
        suite.expect(!AutomationSupport.scheduleMatches(wrongDay, at: monday, calendar: calendar),
                     "a different weekday does not fire")

        // A round trip keeps both halves of a rule.
        let original = rule(.display(connected: true), .quickToggle(id: "emptyTrash"))
        let data = try? JSONEncoder().encode(original)
        let decoded = data.flatMap { try? JSONDecoder().decode(AutomationRule.self, from: $0) }
        suite.expect(decoded == original, "a rule round-trips through JSON")
        suite.expect(AutomationSupport.feature(for: .feature(id: "keepAwake", enabled: true))
                     == .keepAwake,
                     "a feature action resolves the feature")
    }
}
