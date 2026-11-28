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

        let profile = MacSettingsProfile(name: "Desk", values: [
            MacSetting.dockAutoHide.rawValue: .bool(true),
            MacSetting.keyboardRepeatRate.rawValue: .number(2),
            MacSetting.screenshotFormat.rawValue: .text("jpg"),
        ])
        let components = MacSettingsSupport.components(for: [.dockAutoHide, .finderShowHidden,
                                                             .keyboardRepeatRate])
        suite.expect(components == [.dock, .finder],
                     "restart targets come from the changed settings")

        // The profile survives a round trip.
        let encoded = try? JSONEncoder().encode(profile)
        let decoded = encoded.flatMap { try? JSONDecoder().decode(MacSettingsProfile.self, from: $0) }
        suite.expect(decoded == profile, "a profile round-trips through JSON")

        suite.expect(MacSetting.dockAutoHide.domain == "com.apple.dock"
                     && MacSetting.keyboardRepeatRate.domain == kCFPreferencesAnyApplication as String
                     && MacSetting.finderShowExtensions.domain == kCFPreferencesAnyApplication as String,
                     "settings read their own domains")
        transaction(suite)
    }

    private static func transaction(_ suite: TestSuite) {
        var raw: [MacSetting: Any] = [.dockAutoHide: "YES", .finderShowHidden: false]
        var writes: [MacSetting] = []
        var blocked = Set<MacSetting>()
        func write(_ setting: MacSetting, _ value: Any?) -> Bool {
            writes.append(setting)
            guard !blocked.contains(setting) else { return false }
            raw[setting] = value
            return true
        }

        let profile = MacSettingsProfile(name: "Desk", values: [
            MacSetting.dockAutoHide.rawValue: .bool(false),
            MacSetting.dockOrientation.rawValue: .text("left"),
            MacSetting.finderShowHidden.rawValue: .bool(false),
            MacSetting.keyboardRepeatRate.rawValue: .number(3),
        ])
        blocked = [.keyboardRepeatRate]
        let apply = MacSettingsSupport.apply(profile, read: { raw[$0] }, write: write)
        suite.expect(!apply.succeeded && apply.changed == [.dockAutoHide, .dockOrientation]
                     && apply.undo.map(\.setting) == apply.changed,
                     "partial application journals only successful writes")
        suite.expect(writes == [.dockAutoHide, .dockOrientation, .keyboardRepeatRate],
                     "live equal keys are skipped")
        raw[.finderShowHidden] = true

        blocked = [.dockOrientation]
        writes = []
        let partialUndo = MacSettingsSupport.restore(apply.undo, write: write)
        suite.expect(!partialUndo.succeeded && partialUndo.changed == [.dockAutoHide]
                     && partialUndo.undo.map(\.setting) == [.dockOrientation],
                     "Undo retains only the failed entry")
        suite.expect(raw[.dockAutoHide] as? String == "YES" && raw[.finderShowHidden] as? Bool == true,
                     "Undo restores the exact original representation and leaves unrelated edits alone")
        suite.expect(writes == [.dockAutoHide, .dockOrientation], "undo is limited to originally touched keys")

        blocked = []
        let retry = MacSettingsSupport.restore(partialUndo.undo, write: write)
        suite.expect(retry.succeeded && retry.undo.isEmpty && raw[.dockOrientation] == nil,
                     "retry removes a key that was originally absent")

        let invalid = MacSettingsProfile(name: "Invalid", values: [MacSetting.dockOrientation.rawValue: .text("bad")])
        writes = []
        let rejected = MacSettingsSupport.apply(invalid, read: { raw[$0] }, write: write)
        suite.expect(!rejected.succeeded && writes.isEmpty && rejected.undo.isEmpty,
                     "untrusted typed profile values are validated before touching preferences")

        let unreadable = MacSettingsSupport.apply(profile, prepare: { _ in false },
                                                   read: { _ in nil }, write: write)
        suite.expect(!unreadable.succeeded && writes.isEmpty && unreadable.undo.isEmpty,
                     "a domain that cannot be read is not treated as an absent value")

        let failAfterWrite = MacSettingsProfile(name: "Sync failure", values: [
            MacSetting.screenshotFormat.rawValue: .text("jpg"),
        ])
        let failed = MacSettingsSupport.apply(failAfterWrite, read: { raw[$0] }, write: { setting, value in
            raw[setting] = value
            return value == nil
        })
        suite.expect(!failed.succeeded && failed.changed.isEmpty
                     && failed.undo.isEmpty && raw[.screenshotFormat] == nil,
                     "a visible change after a failed write is rolled back without reporting success")

        let failedRollback = MacSettingsSupport.apply(failAfterWrite, read: { raw[$0] }, write: { setting, value in
            raw[setting] = value
            return false
        })
        suite.expect(failedRollback.undo.map(\.setting) == [.screenshotFormat],
                     "failed rollback remains retryable even when the cache already looks restored")
        let restored = MacSettingsSupport.restore(failedRollback.undo, write: write)
        suite.expect(restored.succeeded && writes == [.screenshotFormat],
                     "retry still writes old value to verify synchronization")
    }
}
