// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// Pins the rules engine, the stored formats and the rules file. Everything
/// here is pure, so no window, input source or app activation is needed.
enum AutoInputSourceTests {
    static func run(_ suite: TestSuite) {
        // MARK: Stored format

        let rule = AutoInputSourceRule(
            bundleID: "com.example.Editor",
            appName: "Editor",
            timings: AutoInputSourceTimings(firstActivation: .fixed("com.apple.keylayout.US"),
                                            reactivation: .rememberLast))
        let configuration = AutoInputSourceConfiguration(
            global: AutoInputSourceTimings(firstActivation: .noSwitch,
                                           reactivation: .fixed("com.apple.inputmethod.SCIM")),
            excludedBundleIDs: ["com.example.Terminal"],
            rules: [rule])
        let stored = AutoInputSourceSupport.encodeConfiguration(configuration)
        suite.expect(AutoInputSourceSupport.decodeConfiguration(stored) == configuration,
                     "configuration round-trips through the stored JSON")
        suite.expect(AutoInputSourceSupport.decodeConfiguration(nil) == .empty
                && AutoInputSourceSupport.decodeConfiguration("") == .empty
                && AutoInputSourceSupport.decodeConfiguration("not json") == .empty,
                     "missing or corrupt stored data reads as the empty configuration")

        let exported = AutoInputSourceSupport.exportData(configuration)
        suite.expect((try? JSONSerialization.jsonObject(with: exported)) != nil,
                     "the exported rules file is JSON")
        let imported = AutoInputSourceSupport.importConfiguration(from: exported)
        suite.expect((try? imported.get()) == configuration,
                     "the exported rules file imports as the same configuration")

        // MARK: Sanitizing

        let messy = AutoInputSourceConfiguration(
            global: AutoInputSourceTimings(firstActivation: .followGlobal,
                                           reactivation: .noSwitch),
            excludedBundleIDs: [" com.example.One ", "com.example.One", "", "not a bundle id"],
            rules: [
                AutoInputSourceRule(bundleID: "com.example.One", appName: "  One  "),
                AutoInputSourceRule(bundleID: "com.example.One", appName: "Duplicate"),
                AutoInputSourceRule(bundleID: "bad id", appName: "Bad"),
                AutoInputSourceRule(bundleID: "com.example.Two", appName: ""),
            ])
        let clean = AutoInputSourceSupport.sanitized(messy)
        suite.expect(clean.global.firstActivation == .noSwitch,
                     "a global default cannot follow itself")
        suite.expect(clean.excludedBundleIDs == ["com.example.One"],
                     "exclusions are trimmed, validated and deduplicated")
        suite.expect(clean.rules.map(\.bundleID) == ["com.example.One", "com.example.Two"],
                     "rules keep the first entry per app and drop invalid ids")
        suite.expect(clean.rules.first?.appName == "One",
                     "a rule's app name is trimmed")
        suite.expect(clean.rules.last?.appName == "com.example.Two",
                     "an empty app name falls back to the bundle id")

        var manyRules: [AutoInputSourceRule] = []
        for index in 0..<(AutoInputSourceConfiguration.maxRules + 20) {
            manyRules.append(AutoInputSourceRule(bundleID: "com.example.App\(index)",
                                                 appName: "App \(index)"))
        }
        let capped = AutoInputSourceSupport.sanitized(
            AutoInputSourceConfiguration(rules: manyRules))
        suite.expect(capped.rules.count == AutoInputSourceConfiguration.maxRules,
                     "the rule list is capped at its limit")

        // MARK: Decisions

        let enabled: Set<String> = ["com.apple.keylayout.US", "com.apple.inputmethod.SCIM"]
        func decide(_ bundleID: String, first: Bool,
                    _ configuration: AutoInputSourceConfiguration,
                    last: [String: String] = [:],
                    current: String? = "com.apple.inputmethod.SCIM",
                    enabled: Set<String> = enabled) -> AutoInputSourceSupport.Decision {
            AutoInputSourceSupport.decision(bundleID: bundleID, firstActivation: first,
                                            configuration: configuration, lastSources: last,
                                            enabledSourceIDs: enabled,
                                            currentSourceID: current)
        }

        let follows = AutoInputSourceConfiguration(
            global: AutoInputSourceTimings(firstActivation: .fixed("com.apple.keylayout.US"),
                                           reactivation: .fixed("com.apple.inputmethod.SCIM")),
            rules: [AutoInputSourceRule(
                bundleID: "com.example.Editor", appName: "Editor",
                timings: AutoInputSourceTimings(firstActivation: .followGlobal,
                                                reactivation: .followGlobal))])
        suite.expect(decide("com.example.Editor", first: true, follows) == .select("com.apple.keylayout.US"),
                     "a rule that follows the global default uses the launch behavior")
        suite.expect(decide("com.example.Editor", first: false, follows) == .stay,
                     "the same rule on reactivation uses the activation behavior, which is already active")
        suite.expect(decide("com.example.Other", first: true, follows) == .select("com.apple.keylayout.US"),
                     "an app with no rule uses the global launch behavior")

        let overridden = AutoInputSourceConfiguration(
            global: AutoInputSourceTimings(firstActivation: .noSwitch,
                                           reactivation: .noSwitch),
            rules: [AutoInputSourceRule(
                bundleID: "com.example.Editor", appName: "Editor",
                timings: AutoInputSourceTimings(firstActivation: .fixed("com.apple.keylayout.US"),
                                                reactivation: .fixed("com.apple.keylayout.US")))])
        suite.expect(decide("com.example.Editor", first: true, overridden) == .select("com.apple.keylayout.US"),
                     "a rule overrides the global default")
        suite.expect(decide("com.example.Other", first: true, overridden) == .stay,
                     "an app without a rule keeps the global no-switch answer")

        let excluded = AutoInputSourceConfiguration(
            global: AutoInputSourceTimings(firstActivation: .fixed("com.apple.keylayout.US"),
                                           reactivation: .fixed("com.apple.keylayout.US")),
            excludedBundleIDs: ["com.example.Terminal"],
            rules: [AutoInputSourceRule(
                bundleID: "com.example.Terminal", appName: "Terminal",
                timings: AutoInputSourceTimings(firstActivation: .fixed("com.apple.keylayout.US"),
                                                reactivation: .fixed("com.apple.keylayout.US")))])
        suite.expect(decide("com.example.Terminal", first: true, excluded) == .stay,
                     "an exclusion wins over a rule and the global default")

        let fixedMissing = AutoInputSourceConfiguration(
            global: AutoInputSourceTimings(firstActivation: .fixed("com.example.disabled"),
                                           reactivation: .fixed("com.example.disabled")))
        suite.expect(decide("com.example.Editor", first: true, fixedMissing) == .stay,
                     "a fixed source that is no longer enabled is not selected")
        suite.expect(decide("com.example.Editor", first: true,
                            AutoInputSourceConfiguration(
                                global: AutoInputSourceTimings(
                                    firstActivation: .fixed("com.apple.inputmethod.SCIM"),
                                    reactivation: .fixed("com.apple.inputmethod.SCIM")))) == .stay,
                     "the source already active is never selected again")

        let remembered = AutoInputSourceConfiguration(rules: [
            AutoInputSourceRule(bundleID: "com.example.Editor", appName: "Editor",
                                timings: AutoInputSourceTimings(firstActivation: .rememberLast,
                                                                reactivation: .rememberLast))])
        suite.expect(decide("com.example.Editor", first: false, remembered,
                            last: ["com.example.Editor": "com.apple.keylayout.US"])
                     == .select("com.apple.keylayout.US"),
                     "remember last uses the source the app last typed with")
        suite.expect(decide("com.example.Editor", first: false, remembered) == .stay,
                     "an app with no remembered source stays put")
        suite.expect(decide("com.example.Editor", first: false, remembered,
                            last: ["com.example.Editor": "com.example.disabled"]) == .stay,
                     "a remembered source that is no longer enabled is ignored")

        suite.expect(decide("", first: true, fixedMissing) == .stay,
                     "an empty bundle id never switches")
        suite.expect(decide("com.example.Other", first: true,
                            AutoInputSourceConfiguration(
                                global: AutoInputSourceTimings(firstActivation: .noSwitch,
                                                               reactivation: .noSwitch))) == .stay,
                     "the no-switch behavior answers with no change")

        // MARK: Last sources

        let lastRaw = AutoInputSourceSupport.encodeLastSources(
            ["com.example.Editor": "com.apple.keylayout.US",
             "com.example.Terminal": "com.apple.inputmethod.SCIM"])
        suite.expect(AutoInputSourceSupport.decodeLastSources(lastRaw).count == 2,
                     "last sources round-trip through the stored JSON")
        suite.expect(AutoInputSourceSupport.decodeLastSources("not json").isEmpty,
                     "corrupt last sources read as empty")
        let pruned = AutoInputSourceSupport.pruned(
            ["com.example.Editor": "com.apple.keylayout.US",
             "com.example.Terminal": "com.example.disabled",
             "bad id": "com.apple.keylayout.US"],
            enabledSourceIDs: enabled)
        suite.expect(pruned == ["com.example.Editor": "com.apple.keylayout.US"],
                     "pruning drops disabled sources and malformed app ids")

        // MARK: Rules file failures

        let wrongFormat = Data(#"{"format":"other","version":1,"rules":[]}"#.utf8)
        suite.expect(AutoInputSourceSupport.importConfiguration(from: wrongFormat)
            == .failure(.unsupportedFormat),
                     "a file for another feature is refused")
        let newer = Data(#"{"format":"tina.auto-input-source","version":99,"rules":[]}"#.utf8)
        suite.expect(AutoInputSourceSupport.importConfiguration(from: newer)
            == .failure(.newerVersion),
                     "a file from a newer version is refused rather than half-read")
        suite.expect(AutoInputSourceSupport.importConfiguration(from: Data("not json".utf8))
            == .failure(.unreadable),
                     "an unreadable file is refused")
        let handWritten = Data("""
            {"global":{"firstActivation":{"kind":"fixed","sourceID":"com.apple.keylayout.US"},
                       "reactivation":{"kind":"noSwitch"}},
             "rules":[{"bundleID":"com.example.Editor","appName":"Editor",
                       "timings":{"firstActivation":{"kind":"rememberLast"},
                                  "reactivation":{"kind":"noSwitch"}}}]}
            """.utf8)
        guard case .success(let importedHandWritten) = AutoInputSourceSupport
            .importConfiguration(from: handWritten) else {
            suite.expect(false, "a hand-written dotfile without the envelope still imports")
            return
        }
        suite.expect(importedHandWritten.rules.count == 1
                && importedHandWritten.global.firstActivation == .fixed("com.apple.keylayout.US"),
                     "a hand-written dotfile imports with its rules intact")

        // MARK: Catalog, defaults and backup

        suite.expect(AppFeature.autoInputSource.group == .mouseKeyboard,
                     "automatic input source lives under Mouse and keyboard")
        suite.expect(AppFeature.autoInputSource.installedByDefault == false,
                     "the feature is opt-in")
        suite.expect(AppFeature.autoInputSource.enabledKeys == [DefaultsKey.autoInputSourceEnabled],
                     "the feature's own switch is its enable key")
        suite.expect(AppFeature.autoInputSource.permissions.isEmpty,
                     "switching input sources asks for no system permission")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.autoInputSourceData] as? String == "",
                     "an empty rule set is the registered default")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.autoInputSourceEnabled] as? Bool == false,
                     "automatic switching starts switched off")
        suite.expect(!SettingsBackupSupport.exportKeys().isDisjoint(with: [
            DefaultsKey.autoInputSourceData, DefaultsKey.autoInputSourceEnabled,
            DefaultsKey.panelUtilityAutoInputSource]),
                     "rules and the panel row travel in settings backups")
        suite.expect(SettingsBackupSupport.exportKeys()
            .isDisjoint(with: [DefaultsKey.autoInputSourceLastSources]),
                     "last-used sources never leave this Mac in a settings backup")

        // MARK: Copy

        var fields = 0
        for language in AppLanguage.allCases {
            let strings = FeatureStrings.autoInputSource(language)
            let values = Mirror(reflecting: strings).children.compactMap { $0.value as? String }
            fields = values.count
            suite.expect(values.allSatisfy { !$0.isEmpty },
                         "every automatic input source string is filled in \(language.rawValue)")
            suite.expect(values.allSatisfy { !$0.contains("\u{2014}") },
                         "no em-dash in visible automatic input source copy (\(language.rawValue))")
        }
        suite.expect(fields >= 40, "the strings set is complete, got \(fields) fields")
        suite.expect(FeatureStrings.autoInputSource(.zhHans).title
                != FeatureStrings.autoInputSource(.enUS).title,
                     "the Chinese title is translated")
        suite.expect(String(format: FeatureStrings.autoInputSource(.enUS).importSuccessFormat, 3)
            .contains("3"),
                     "the import result names the number of rules")
    }
}
