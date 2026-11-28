// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox
import Foundation

enum InputRemapSupportTests {
    static func run(_ suite: TestSuite) {
        let option = GlobalShortcutModifiers.option
        func rule(_ source: UInt16, _ target: UInt16,
                  modifiers: GlobalShortcutModifiers = [],
                  enabled: Bool = true,
                  excluded: [String] = []) -> InputRemapRule {
            InputRemapRule(sourceKeyCode: source, sourceModifiers: modifiers,
                           targetKeyCode: target, targetModifiers: [],
                           enabled: enabled, excludedBundleIDs: excluded)
        }

        // A rule that maps a key to itself is meaningless and dropped.
        let identity = rule(54, 54)
        suite.expect(InputRemapSupport.sanitized([identity]).isEmpty,
                     "a key cannot be remapped to itself")

        // Duplicate sources collapse; a disabled twin does not shadow an
        // enabled one, because the key differs.
        let first = rule(54, 55)
        let second = rule(54, 56)
        let cleaned = InputRemapSupport.sanitized([first, second])
        suite.expect(cleaned.count == 1 && cleaned[0].targetKeyCode == 55,
                     "the first rule for a source wins")

        let disabled = rule(54, 56, enabled: false)
        suite.expect(InputRemapSupport.sanitized([first, disabled]).count == 2,
                     "a disabled rule with the same source is kept but inert")

        // Lookup respects modifiers, enablement and exclusions.
        suite.expect(InputRemapSupport.rule(for: 54, modifiers: [], bundleID: "com.a",
                                            rules: [first])?.targetKeyCode == 55,
                     "an enabled rule matches")
        suite.expect(InputRemapSupport.rule(for: 54, modifiers: option, bundleID: "com.a",
                                            rules: [first]) == nil,
                     "the modifiers must match exactly")
        suite.expect(InputRemapSupport.rule(for: 54, modifiers: [], bundleID: "com.a",
                                            rules: [disabled]) == nil,
                     "a disabled rule does not match")

        let excluded = rule(54, 55, excluded: ["com.game"])
        suite.expect(InputRemapSupport.rule(for: 54, modifiers: [], bundleID: "com.game",
                                            rules: [excluded]) == nil,
                     "an excluded app gets the original key")
        suite.expect(InputRemapSupport.rule(for: 54, modifiers: [], bundleID: "com.other",
                                            rules: [excluded])?.targetKeyCode == 55,
                     "other apps still get the rule")
        suite.expect(InputRemapSupport.rule(for: 54, modifiers: [], bundleID: nil,
                                            rules: [excluded])?.targetKeyCode == 55,
                     "an unknown frontmost app still gets the rule")

        // Duplicate sources are reported for the page.
        let duplicates = InputRemapSupport.duplicateSourceIDs([first, rule(54, 57)])
        suite.expect(duplicates.count == 2, "both rules with one source are marked")
        suite.expect(InputRemapSupport.duplicateSourceIDs([first, rule(55, 57)]).isEmpty,
                     "different sources are not duplicates")

        // The cap keeps the list bounded.
        let many = (0..<(InputRemapSupport.maximumRules + 10)).map { index in
            rule(100 + UInt16(index), 200)
        }
        suite.expect(InputRemapSupport.sanitized(many).count == InputRemapSupport.maximumRules,
                     "the rule list is capped")

        // A rule round-trips through JSON, including the modifiers.
        let withModifiers = rule(54, 55, modifiers: option, excluded: ["com.a"])
        let data = try? JSONEncoder().encode(withModifiers)
        let decoded = data.flatMap { try? JSONDecoder().decode(InputRemapRule.self, from: $0) }
        suite.expect(decoded == withModifiers, "a rule round-trips through JSON")
        suite.expect(decoded?.sourceModifiers == option,
                     "the modifier set survives the round trip")

        let toA = rule(UInt16(kVK_ANSI_B), UInt16(kVK_ANSI_A))
        suite.expect(InputRemapSupport.sanitized([toA]) == [toA],
                     "bare A is a real target even though its virtual key code is zero")
        suite.expect(GlobalShortcut(keyCode: Int64(kVK_ANSI_A), modifiers: []).hasPrintableKey,
                     "the bare-key recorder accepts virtual key code zero")

        // A repeat or release never consults the current layer, frontmost app,
        // or rewritten rules again. An unobserved down must not become a remap.
        var presses = InputRemapSupport.Presses()
        var lookups = 0
        func lookup() -> InputRemapRule? {
            lookups += 1
            return toA
        }
        let source = toA.sourceKeyCode
        let target = GlobalShortcut(keyCode: Int64(kVK_ANSI_A), modifiers: [])
        suite.expect(presses.target(for: source, phase: .repeatDown, matching: lookup) == nil,
                     "a key already repeating when the tap starts passes through")
        suite.expect(presses.target(for: source, phase: .up, matching: lookup) == nil && lookups == 0,
                     "an unmatched release passes through without remapping")
        suite.expect(presses.target(for: source, phase: .down, matching: lookup) == target,
                     "a fresh press selects a replacement")
        suite.expect(presses.target(for: source, phase: .repeatDown) { nil } == target,
                     "changed modifiers or an excluded app do not switch the target of a held key")
        suite.expect(presses.target(for: source, phase: .up) { nil } == target,
                     "the replacement receives the matching key-up")
        suite.expect(presses.target(for: source, phase: .down) { nil } == nil,
                     "a new press after release re-evaluates the current exclusion")
        suite.expect(presses.target(for: source, phase: .repeatDown, matching: lookup) == nil,
                     "a passthrough press does not start remapping when the app changes")
        suite.expect(presses.target(for: source, phase: .up, matching: lookup) == nil && lookups == 1,
                     "a passthrough press keeps its original key-up")
        _ = presses.target(for: source, phase: .down, matching: lookup)
        suite.expect(presses.finish() == [target] && presses.finish().isEmpty,
                     "stopping releases only held replacements once")
        suite.expect(presses.target(for: source, phase: .up, matching: lookup) == nil,
                     "restarting does not inherit an old press")

        eventReplacement(in: suite)
    }

    private static func eventReplacement(in suite: TestSuite) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_B), keyDown: true) else {
            suite.expect(false, "the fixture can construct an offline keyboard event")
            return
        }
        event.timestamp = 123_456
        event.location = CGPoint(x: 17, y: 32)
        event.flags = [.maskCommand, .maskAlphaShift]
        event.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
        event.setIntegerValueField(.eventSourceUserData, value: 42)
        let target = GlobalShortcut(keyCode: Int64(kVK_LeftArrow), modifiers: [.option])
        let replacement = InputRemapService.replacement(for: event, target: target)
        suite.expect(replacement.type == .keyDown
                     && replacement.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_LeftArrow),
                     "a remap returns one event with the new virtual key")
        suite.expect(replacement.getIntegerValueField(.keyboardEventAutorepeat) == 1
                     && replacement.getIntegerValueField(.eventSourceUserData) == 42
                     && replacement.timestamp == event.timestamp && replacement.location == event.location,
                     "the forwarded replacement preserves repeat, source metadata, time and location")
        suite.expect(replacement.flags.contains([.maskAlternate, .maskAlphaShift, .maskSecondaryFn, .maskNumericPad])
                     && !replacement.flags.contains(.maskCommand),
                     "the replacement preserves Caps Lock, changes the chord and sets target key flags")

        event.flags = []
        event.keyboardSetUnicodeString(stringLength: 1, unicodeString: [0x2605])
        let printable = InputRemapService.replacement(
            for: event, target: GlobalShortcut(keyCode: Int64(kVK_ANSI_A), modifiers: []))
        var unicode = [UniChar](repeating: 0, count: 8)
        var length = 0
        printable.keyboardGetUnicodeString(maxStringLength: unicode.count, actualStringLength: &length,
                                            unicodeString: &unicode)
        suite.expect(length > 0 && unicode[0] != 0x2605,
                     "rewriting a printable key does not forward the old key's Unicode override")
    }
}
