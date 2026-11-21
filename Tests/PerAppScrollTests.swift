// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// Per-app smooth scrolling and the hold key (issue #6): the stored table,
/// its clamping, the multiplier a record resolves to, and the hold shortcut.
/// The two wheel taps have separate routing tests.
enum PerAppScrollTests {
    static func run(_ suite: TestSuite) {
        registeredDefaults(suite)
        decodingAndSanitizing(suite)
        effectiveSettings(suite)
        holdPreferences(suite)
    }

    private static func registeredDefaults(_ suite: TestSuite) {
        suite.expect(Defaults.registeredDefaults[DefaultsKey.scrollPerAppOverrides] as? String == "",
                     "the per-app table ships empty")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.scrollHoldEnabled] as? Bool == false
                && Defaults.registeredDefaults[DefaultsKey.scrollHoldModifier] as? String
                    == ScrollHorizontalModifier.control.rawValue
                && Defaults.registeredDefaults[DefaultsKey.scrollHoldAction] as? String
                    == ScrollHoldAction.precise.rawValue
                && Defaults.registeredDefaults[DefaultsKey.scrollHoldFactor] as? Int
                    == ScrollHoldPreferences.defaultFactor,
                     "the hold key ships off with Control, Pause smoothing and 4x")
        suite.expect(SettingsBackupSupport.exportKeys().isSuperset(of: [
            DefaultsKey.scrollPerAppOverrides, DefaultsKey.scrollHoldEnabled,
            DefaultsKey.scrollHoldModifier, DefaultsKey.scrollHoldAction,
            DefaultsKey.scrollHoldFactor,
        ]), "backup and restore include every per-app scroll setting")
        suite.expect(AppFeature.smoothScroll.permissions == [.accessibility]
                && AppFeature.smoothScroll.enabledKeys == [DefaultsKey.smoothScrollEnabled],
                     "per-app settings stay under Smooth scrolling and add no permission")
    }

    private static func decodingAndSanitizing(_ suite: TestSuite) {
        let source = ScrollPerAppOverride(bundleID: "com.example.editor",
                                          smoothing: .custom,
                                          step: 60,
                                          speedPercent: 150,
                                          invertVertical: true)
        let encoded = ScrollPerAppSupport.encode([source])
        suite.expect(ScrollPerAppSupport.decode(encoded) == [source],
                     "a complete record survives the JSON round trip")

        suite.expect(ScrollPerAppSupport.decode("").isEmpty
                && ScrollPerAppSupport.decode("not json").isEmpty
                && ScrollPerAppSupport.decode("{}").isEmpty,
                     "an empty, malformed or wrongly shaped table decodes to nothing instead of failing")

        let tolerant = ScrollPerAppSupport.decode("""
        [{"bundleID":"com.example.app","smoothing":"sideways","step":999,"speedPercent":0},
         {"bundleID":"  com.example.space  ","smoothing":"custom","step":5,"speedPercent":900},
         {"bundleID":"/usr/local/bin/tool"},
         {"bundleID":""},
         {"bundleID":"com.example.app","smoothing":"off"}]
        """)
        suite.expect(tolerant.count == 2,
                     "records that cannot name an app are dropped and repeated apps fold")
        let space = tolerant.first { $0.bundleID == "com.example.space" }
        let repeated = tolerant.first { $0.bundleID == "com.example.app" }
        suite.expect(space?.step == SmoothScrollSupport.stepRange.lowerBound
                && space?.speedPercent == ScrollPerAppSupport.speedRange.upperBound,
                     "stored numbers are clamped to what the sliders offer")
        suite.expect(repeated?.smoothing == .off,
                     "the last record for a repeated app wins")

        let unknownMode = ScrollPerAppSupport.decode("""
        [{"bundleID":"com.example.app","smoothing":"bogus","speedPercent":100}]
        """)
        suite.expect(unknownMode.first?.smoothing == .inherit,
                     "an unknown mode falls back to following the global setting")

        let lookup = [
            ScrollPerAppOverride(bundleID: "com.example.app", smoothing: .off),
            ScrollPerAppOverride(bundleID: "com.example.helper", smoothing: .custom, step: 80),
        ]
        suite.expect(ScrollPerAppSupport.override(in: lookup,
                                                  matchingBundleIdentifiers: ["com.example.helper"])?
                        .step == 80,
                     "a helper identity that matches is used")
        suite.expect(ScrollPerAppSupport.override(in: lookup,
                                                  matchingBundleIdentifiers: ["com.example.unknown"]) == nil,
                     "an app not in the table has no override")
        suite.expect(ScrollPerAppSupport.override(in: lookup, matchingBundleIdentifiers: []) == nil,
                     "no identity asks nothing")
    }

    private static func effectiveSettings(_ suite: TestSuite) {
        let inherit = ScrollPerAppOverride(bundleID: "com.example.inherit")
        let off = ScrollPerAppOverride(bundleID: "com.example.off", smoothing: .off)
        let custom = ScrollPerAppOverride(bundleID: "com.example.custom", smoothing: .custom,
                                          step: 70, speedPercent: 200, invertVertical: true)
        let customInheriting = ScrollPerAppOverride(bundleID: "com.example.custom-default",
                                                    smoothing: .custom)

        suite.expect(ScrollPerAppSupport.step(for: nil, globalStep: 40) == 40
                && ScrollPerAppSupport.step(for: inherit, globalStep: 40) == 40
                && ScrollPerAppSupport.step(for: off, globalStep: 40) == 40,
                     "an app that follows global or turns smoothing off keeps the global step")
        suite.expect(ScrollPerAppSupport.step(for: custom, globalStep: 40) == 70
                && ScrollPerAppSupport.step(for: customInheriting, globalStep: 40) == 40,
                     "a custom app uses its own step, or the global one until it sets one")
        suite.expect(ScrollPerAppSupport.sanitizedStep(0) == nil
                && ScrollPerAppSupport.sanitizedStep(nil) == nil,
                     "zero and a missing step both mean the global step")

        suite.expect(ScrollPerAppSupport.speedScale(for: nil) == 1
                && ScrollPerAppSupport.speedScale(for: inherit) == 1
                && ScrollPerAppSupport.speedScale(for: off) == 1,
                     "only a custom record scales the distance")
        suite.expectClose(ScrollPerAppSupport.speedScale(for: custom), 2,
                          "a custom record's speed is a percentage of the global distance")
        let clamped: [Int: Double] = [1: 0.25, 1000: 4]
        for (percent, expected) in clamped {
            let record = ScrollPerAppOverride(bundleID: "com.example.speed", smoothing: .custom,
                                              speedPercent: percent)
            suite.expectClose(ScrollPerAppSupport.speedScale(for: record), expected,
                              "custom speed \(percent)% clamps before scaling")
        }

        suite.expect(ScrollPerAppSupport.disablesSmoothing(nil) == false
                && ScrollPerAppSupport.disablesSmoothing(inherit) == false
                && ScrollPerAppSupport.disablesSmoothing(custom) == false
                && ScrollPerAppSupport.disablesSmoothing(off),
                     "only the Off mode disables smoothing")
        suite.expect(custom.invertVertical == true && customInheriting.invertVertical == nil,
                     "a record's direction is tri-state: invert, normal or follow global")
    }

    private static func holdPreferences(_ suite: TestSuite) {
        let disabled = ScrollHoldPreferences(
            isAvailable: false,
            boolFor: { _ in true },
            stringFor: { _ in ScrollHorizontalModifier.option.rawValue },
            intFor: { _ in 6 })
        suite.expect(disabled.modifier == nil,
                     "uninstalling Smooth scrolling stands the hold key down even when its switch is on")

        let prefs = ScrollHoldPreferences(
            isAvailable: true,
            boolFor: { $0 == DefaultsKey.scrollHoldEnabled },
            stringFor: { key in
                switch key {
                case DefaultsKey.scrollHoldModifier: return ScrollHorizontalModifier.command.rawValue
                case DefaultsKey.scrollHoldAction: return ScrollHoldAction.slower.rawValue
                default: return nil
                }
            },
            intFor: { $0 == DefaultsKey.scrollHoldFactor ? 5 : 0 })
        suite.expect(prefs.modifier == .command && prefs.action == .slower && prefs.factor == 5,
                     "an installed hold key resolves its modifier, action and amount")

        let fallback = ScrollHoldPreferences(
            isAvailable: true,
            boolFor: { $0 == DefaultsKey.scrollHoldEnabled },
            stringFor: { _ in "bogus" },
            intFor: { _ in 0 })
        suite.expect(fallback.modifier == .control && fallback.action == .precise
                && fallback.factor == ScrollHoldPreferences.defaultFactor,
                     "garbage storage falls back to Control, Pause smoothing and the default amount")

        suite.expectClose(ScrollHoldAction.precise.scale(factor: 6), 1,
                          "Pause smoothing bypasses rather than scaling")
        suite.expectClose(ScrollHoldAction.faster.scale(factor: 6), 6,
                          "Faster multiplies the glide distance")
        suite.expectClose(ScrollHoldAction.slower.scale(factor: 4), 0.25,
                          "Slower divides the glide distance")
        suite.expect(ScrollHoldPreferences.sanitizedFactor(0) == ScrollHoldPreferences.defaultFactor
                && ScrollHoldPreferences.sanitizedFactor(1) == ScrollHoldPreferences.factorRange.lowerBound
                && ScrollHoldPreferences.sanitizedFactor(99) == ScrollHoldPreferences.factorRange.upperBound,
                     "the hold amount clamps to its range with a default")

        let event = CGEvent(scrollWheelEvent2Source: nil, units: .line,
                            wheelCount: 1, wheel1: 1, wheel2: 0, wheel3: 0)!
        event.flags = .maskCommand
        suite.expect(prefs.claims(event), "the hold key claims its own modifier")
        event.flags = [.maskCommand, .maskShift]
        suite.expect(!prefs.claims(event),
                     "the hold key never shadows a modifier combination")
        event.flags = .maskAlternate
        suite.expect(!prefs.claims(event), "another modifier is not claimed")
    }
}
