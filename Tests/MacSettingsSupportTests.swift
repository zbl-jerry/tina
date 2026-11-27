// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

enum MacSettingsSupportTests {
    static func run(_ suite: TestSuite) {
        // Raw preference folding.
        suite.expect(MacSettingsSupport.value(for: .dockAutoHide, raw: true) == .bool(true),
                     "a real boolean is accepted")
        suite.expect(MacSettingsSupport.value(for: .finderShowHidden, raw: 1) == .bool(true),
                     "a number folds to a boolean")
        suite.expect(MacSettingsSupport.value(for: .finderShowExtensions, raw: "NO") == .bool(false),
                     "the legacy string spellings fold")
        suite.expect(MacSettingsSupport.value(for: .finderShowPathBar, raw: "maybe") == nil,
                     "an unreadable flag is not guessed")
        suite.expect(MacSettingsSupport.value(for: .keyboardRepeatRate, raw: 6) == .number(6),
                     "a number in range is accepted")
        suite.expect(MacSettingsSupport.value(for: .keyboardRepeatRate, raw: 0) == nil
                     && MacSettingsSupport.value(for: .keyboardRepeatRate, raw: 500) == nil,
                     "an out-of-range number is rejected")
        suite.expect(MacSettingsSupport.value(for: .keyboardRepeatDelay, raw: "25") == .number(25),
                     "a numeric string is accepted where the setting is numeric")
        suite.expect(MacSettingsSupport.value(for: .dockOrientation, raw: "left") == .text("left"),
                     "a known choice is accepted")
        suite.expect(MacSettingsSupport.value(for: .dockOrientation, raw: "diagonal") == nil,
                     "an unknown choice is rejected")
        suite.expect(MacSettingsSupport.value(for: .screenshotLocation, raw: "~/Desktop")
                     == .text("~/Desktop"),
                     "a free-text path is kept")

        // Differences: ordered by the catalog, missing current values count.
        let profile = MacSettingsProfile(name: "Desk", values: [
            MacSetting.dockAutoHide.rawValue: .bool(true),
            MacSetting.keyboardRepeatRate.rawValue: .number(2),
            MacSetting.screenshotFormat.rawValue: .text("jpg"),
        ])
        let current: [String: MacSettingValue] = [
            MacSetting.dockAutoHide.rawValue: .bool(false),
            MacSetting.keyboardRepeatRate.rawValue: .number(2),
            MacSetting.screenshotFormat.rawValue: .text("png"),
        ]
        let differences = MacSettingsSupport.differences(between: current, and: profile)
        suite.expect(differences == [.dockAutoHide, .screenshotFormat],
                     "only the differing settings are applied, got \(differences)")

        let missing = MacSettingsSupport.differences(between: [:], and: profile)
        suite.expect(missing == [.dockAutoHide, .keyboardRepeatRate, .screenshotFormat],
                     "a missing current value is a difference")

        let components = MacSettingsSupport.components(for: [.dockAutoHide, .finderShowHidden,
                                                             .keyboardRepeatRate])
        suite.expect(components == [.dock, .finder],
                     "restart targets come from the changed settings")

        // The profile survives a round trip.
        let encoded = try? JSONEncoder().encode(profile)
        let decoded = encoded.flatMap { try? JSONDecoder().decode(MacSettingsProfile.self, from: $0) }
        suite.expect(decoded == profile, "a profile round-trips through JSON")

        suite.expect(MacSetting.dockAutoHide.domain == "com.apple.dock"
                     && MacSetting.keyboardRepeatRate.domain == kCFPreferencesAnyApplication as String,
                     "settings read their own domains")
    }
}
