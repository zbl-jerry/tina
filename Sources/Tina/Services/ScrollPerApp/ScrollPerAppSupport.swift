// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// One app's place in the smooth scrolling picture. The table is stored as
/// JSON in `DefaultsKey.scrollPerAppOverrides`; every field except the app
/// itself has an "inherit" spelling so the table never has to repeat the
/// global setting.
enum ScrollPerAppSmoothing: String, CaseIterable, Codable {
    case inherit
    case off
    case custom
}

struct ScrollPerAppOverride: Equatable, Codable {
    let bundleID: String
    var smoothing: ScrollPerAppSmoothing = .inherit
    /// Pixels per wheel tick while smoothing is `.custom`; nil inherits.
    var step: Int?
    /// Percentage of the global glide distance while `.custom`.
    var speedPercent: Int = ScrollPerAppSupport.defaultSpeedPercent
    /// nil follows the global vertical inversion; true or false overrides it.
    var invertVertical: Bool?

    init(bundleID: String,
         smoothing: ScrollPerAppSmoothing = .inherit,
         step: Int? = nil,
         speedPercent: Int = ScrollPerAppSupport.defaultSpeedPercent,
         invertVertical: Bool? = nil) {
        self.bundleID = bundleID
        self.smoothing = smoothing
        self.step = step
        self.speedPercent = speedPercent
        self.invertVertical = invertVertical
    }

    /// A hand-edited or older record must never make the tap queue a
    /// nonsensical distance: unknown modes fall back to inheriting, numbers
    /// are clamped, and an absent step stays absent.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleID = try container.decodeIfPresent(String.self, forKey: .bundleID) ?? ""
        let storedSmoothing = (try? container.decodeIfPresent(String.self,
                                                              forKey: .smoothing)) ?? nil
        smoothing = storedSmoothing.flatMap(ScrollPerAppSmoothing.init(rawValue:)) ?? .inherit
        step = ScrollPerAppSupport.sanitizedStep(
            try container.decodeIfPresent(Int.self, forKey: .step))
        speedPercent = ScrollPerAppSupport.sanitizedSpeedPercent(
            try container.decodeIfPresent(Int.self, forKey: .speedPercent)
                ?? ScrollPerAppSupport.defaultSpeedPercent)
        invertVertical = try container.decodeIfPresent(Bool.self, forKey: .invertVertical)
    }
}

/// The pure half of per-app scrolling: decoding, clamping and the numbers the
/// two wheel taps read. Kept free of AppKit so the unit harness can pin it.
enum ScrollPerAppSupport {
    static let speedRange = 25...400
    static let defaultSpeedPercent = 100

    /// The stored table. Invalid JSON means an empty table, not a crash; the
    /// next successful write repairs the string.
    static func decode(_ raw: String) -> [ScrollPerAppOverride] {
        guard !raw.isEmpty, let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([ScrollPerAppOverride].self, from: data)
        else { return [] }
        return sanitized(decoded)
    }

    static func encode(_ overrides: [ScrollPerAppOverride]) -> String {
        let sanitized = sanitized(overrides)
        guard !sanitized.isEmpty,
              let data = try? JSONEncoder().encode(sanitized),
              let raw = String(data: data, encoding: .utf8) else { return "" }
        return raw
    }

    /// Drops records that cannot name an app, folds repeated bundle ids
    /// (the last record wins, like a later line in a file), and clamps every
    /// stored number so the event path only sees usable values.
    static func sanitized(_ overrides: [ScrollPerAppOverride]) -> [ScrollPerAppOverride] {
        var ordered: [String] = []
        var byID: [String: ScrollPerAppOverride] = [:]
        for var item in overrides {
            let bundleID = item.bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !bundleID.isEmpty,
                  !bundleID.contains("/"),
                  !bundleID.hasPrefix("."),
                  !bundleID.contains(" ") else { continue }
            item = ScrollPerAppOverride(bundleID: bundleID,
                                        smoothing: item.smoothing,
                                        step: sanitizedStep(item.step),
                                        speedPercent: sanitizedSpeedPercent(item.speedPercent),
                                        invertVertical: item.invertVertical)
            if byID[bundleID] == nil { ordered.append(bundleID) }
            byID[bundleID] = item
        }
        return ordered.compactMap { byID[$0] }
    }

    /// nil keeps the global step. A stored value is clamped to the same range
    /// the slider offers, so a backup from another version cannot exceed it.
    static func sanitizedStep(_ value: Int?) -> Int? {
        // Zero is the "absent" spelling a plist or a hand edit can produce;
        // like a missing key it means the global step.
        guard let value, value != 0 else { return nil }
        return min(max(value, SmoothScrollSupport.stepRange.lowerBound),
                   SmoothScrollSupport.stepRange.upperBound)
    }

    static func sanitizedSpeedPercent(_ value: Int) -> Int {
        min(max(value, speedRange.lowerBound), speedRange.upperBound)
    }

    /// The distance multiplier a custom record asks for. Anything that is not
    /// custom is exactly the global distance.
    static func speedScale(for override: ScrollPerAppOverride?) -> Double {
        guard let override, override.smoothing == .custom else { return 1 }
        return Double(sanitizedSpeedPercent(override.speedPercent)) / 100
    }

    /// The step a record asks for: its own only while custom, with the global
    /// step filling in when the record did not set one.
    static func step(for override: ScrollPerAppOverride?, globalStep: Int) -> Int {
        guard let override, override.smoothing == .custom else { return globalStep }
        return sanitizedStep(override.step) ?? globalStep
    }

    /// Whether this record turns smoothing off for its app.
    static func disablesSmoothing(_ override: ScrollPerAppOverride?) -> Bool {
        override?.smoothing == .off
    }

    /// The flip a raw wheel gets when no other tap will apply it. Only the
    /// vertical axis is configured per app.
    static func applyVerticalInversion(to event: CGEvent, isContinuous: Bool) {
        ScrollWheelSupport.applyDirection(to: event, isContinuous: isContinuous,
                                          invertVertical: true, invertHorizontal: false,
                                          horizontalModifier: nil)
    }

    static func override(in overrides: [ScrollPerAppOverride],
                         matchingBundleIdentifiers identities: [String]) -> ScrollPerAppOverride? {
        guard !overrides.isEmpty, !identities.isEmpty else { return nil }
        let table = Dictionary(overrides.map { ($0.bundleID, $0) },
                               uniquingKeysWith: { _, latest in latest })
        // A helper bundled inside the app answers to the app's identifier too;
        // the first identity that matches is the closest one.
        for identity in identities {
            if let match = table[identity] { return match }
        }
        return nil
    }
}

/// The three things a held key can do to the current glide.
enum ScrollHoldAction: String, CaseIterable {
    case precise
    case slower
    case faster

    init(storageValue: String?) {
        self = storageValue.flatMap(Self.init(rawValue:)) ?? .precise
    }

    /// `.precise` does not scale; it bypasses smoothing entirely.
    func scale(factor: Int) -> Double {
        let clamped = Double(ScrollHoldPreferences.sanitizedFactor(factor))
        switch self {
        case .precise: return 1
        case .slower: return 1 / clamped
        case .faster: return clamped
        }
    }
}

/// Opt-in modifier-held correction, resolved the same way the other scroll
/// preferences are, so uninstalling Smooth scrolling stands it down even when
/// its switch is left on.
struct ScrollHoldPreferences {
    let modifier: ScrollHorizontalModifier?
    let action: ScrollHoldAction
    let factor: Int

    static let factorRange = 2...15
    static let defaultFactor = 4

    init(isAvailable: Bool, boolFor: (String) -> Bool, stringFor: (String) -> String?,
         intFor: (String) -> Int) {
        guard isAvailable, boolFor(DefaultsKey.scrollHoldEnabled) else {
            modifier = nil
            action = .precise
            factor = Self.defaultFactor
            return
        }
        modifier = stringFor(DefaultsKey.scrollHoldModifier)
            .flatMap(ScrollHorizontalModifier.init(rawValue:)) ?? .control
        action = ScrollHoldAction(storageValue: stringFor(DefaultsKey.scrollHoldAction))
        factor = Self.sanitizedFactor(intFor(DefaultsKey.scrollHoldFactor))
    }

    init(defaults: UserDefaults = .standard) {
        self.init(isAvailable: AppFeature.smoothScroll.isAvailable(in: defaults),
                  boolFor: { defaults.bool(forKey: $0) },
                  stringFor: { defaults.string(forKey: $0) },
                  intFor: { defaults.integer(forKey: $0) })
    }

    static func sanitizedFactor(_ value: Int) -> Int {
        guard value != 0 else { return defaultFactor }
        return min(max(value, factorRange.lowerBound), factorRange.upperBound)
    }

    /// The key is claimed only while it is the sole shortcut modifier held, so
    /// the correction never shadows an ordinary app shortcut.
    func claims(_ event: CGEvent) -> Bool {
        guard let modifier else { return false }
        return modifier.isHeldAlone(in: event.flags)
    }
}
