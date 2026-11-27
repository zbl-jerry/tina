// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

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
    }
}
