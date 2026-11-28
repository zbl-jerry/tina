// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

extension GlobalShortcutModifiers: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(Int.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// One key-to-key mapping. The target is another physical key plus an
/// optional modifier set, which covers both "replace a missing key" and
/// "turn an unused key into a shortcut" without a macro system.
struct InputRemapRule: Codable, Equatable, Identifiable {
    var id = UUID()
    var sourceKeyCode: UInt16
    var sourceModifiers: GlobalShortcutModifiers
    var targetKeyCode: UInt16
    var targetModifiers: GlobalShortcutModifiers
    var enabled: Bool = true
    /// Apps where the rule does not apply; the key passes through untouched.
    var excludedBundleIDs: [String] = []
}

enum InputRemapSupport {
    static let maximumRules = 64

    /// Drops invalid rules (a rule may not map a key to itself), removes
    /// duplicates by source combination, and caps the list.
    static func sanitized(_ rules: [InputRemapRule]) -> [InputRemapRule] {
        var seen: Set<String> = []
        var result: [InputRemapRule] = []
        for rule in rules {
            // Key code zero is a real key (ANSI A), not an empty selection.
            guard !(rule.sourceKeyCode == rule.targetKeyCode
                    && rule.sourceModifiers == rule.targetModifiers) else { continue }
            let key = signature(keyCode: rule.sourceKeyCode,
                                modifiers: rule.sourceModifiers) + "|" +
                (rule.enabled ? "1" : "0")
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(rule)
            if result.count >= maximumRules { break }
        }
        return result
    }

    /// The enabled rule for a press, or nil. An excluded app always gets the
    /// original key.
    static func rule(for keyCode: UInt16,
                     modifiers: GlobalShortcutModifiers,
                     bundleID: String?,
                     rules: [InputRemapRule]) -> InputRemapRule? {
        rules.first { rule in
            guard rule.enabled,
                  rule.sourceKeyCode == keyCode,
                  rule.sourceModifiers == modifiers
            else { return false }
            if let bundleID, rule.excludedBundleIDs.contains(bundleID) { return false }
            return true
        }
    }

    /// Rules that share the same source combination; the page marks them so a
    /// later rule cannot silently shadow an earlier one.
    static func duplicateSourceIDs(_ rules: [InputRemapRule]) -> Set<UUID> {
        var counts: [String: [UUID]] = [:]
        for rule in rules where rule.enabled {
            counts[signature(keyCode: rule.sourceKeyCode,
                             modifiers: rule.sourceModifiers), default: []].append(rule.id)
        }
        return Set(counts.values.filter { $0.count > 1 }.flatMap { $0 })
    }

    static func signature(keyCode: UInt16,
                          modifiers: GlobalShortcutModifiers) -> String {
        "\(modifiers.rawValue)-\(keyCode)"
    }

    struct Presses {
        enum Phase { case down, repeatDown, up }

        /// Only mapped presses need storage. A repeat or release without a
        /// matched down must pass through, including after enabling the tap
        /// mid-hold or when a passthrough press crosses an app boundary.
        private var held: [UInt16: GlobalShortcut] = [:]

        mutating func target(for physicalKey: UInt16, phase: Phase,
                             matching: () -> InputRemapRule?) -> GlobalShortcut? {
            switch phase {
            case .down:
                let target = matching().map {
                    GlobalShortcut(keyCode: Int64($0.targetKeyCode), modifiers: $0.targetModifiers)
                }
                held[physicalKey] = target
                return target
            case .repeatDown:
                return held[physicalKey]
            case .up:
                return held.removeValue(forKey: physicalKey)
            }
        }

        mutating func finish() -> [GlobalShortcut] {
            let mapped = Array(held.values)
            held.removeAll()
            return mapped
        }
    }
}
