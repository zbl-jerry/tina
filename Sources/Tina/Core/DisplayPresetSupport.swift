// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// One named snapshot of the connected displays. The model, its validation,
/// display matching, mode choice and the report of an apply are pure so the
/// hardware-facing service stays small and the decisions can be tested
/// without touching a display.
struct DisplayPreset: Codable, Equatable, Identifiable {
    struct Resolution: Codable, Equatable {
        var width: Int
        var height: Int
        var pixelWidth: Int
        var pixelHeight: Int
        var refreshRate: Double
    }

    struct Display: Codable, Equatable {
        /// `vendor:model:serial`, the identity the brightness feature already
        /// uses for DDC paths and display restoration.
        var fingerprint: String
        var name: String
        var isBuiltIn: Bool
        var resolution: Resolution?
        /// 0...1 for the UI value.
        var brightness: Double?
        /// 0...1 for the UI value.
        var volume: Double?
        var muted: Bool?
    }

    struct Trigger: Codable, Equatable {
        enum Event: String, Codable, CaseIterable {
            case connected, disconnected
        }

        var fingerprint: String
        var displayName: String
        var event: Event
    }

    var id: UUID
    var name: String
    var symbol: String
    var displays: [Display]
    var mainDisplayFingerprint: String?
    /// `GlobalShortcut.storageValue`, or nil for no shortcut.
    var shortcut: String?
    var trigger: Trigger?
}

/// A display an automatic rule can watch, as the editor lists it.
struct DisplayPresetCandidate: Identifiable, Hashable {
    var fingerprint: String
    var name: String
    var id: String { fingerprint }
}

/// Outcome of one apply, published so every surface that can start one shows
/// the same per-item failures. Volume writes finish after the synchronous
/// part, so a failure can still be appended while this is the newest report.
struct DisplayPresetReport: Equatable, Identifiable {
    enum FailureKind: Equatable {
        case notConnected
        case resolutionUnsupported
        case resolutionFailed
        case brightnessUnavailable
        case volumeUnavailable
        case mainDisplayFailed
    }

    struct Failure: Equatable {
        var kind: FailureKind
        var displayName: String
    }

    let id: UUID
    let presetID: UUID
    let presetName: String
    var failures: [Failure] = []

    var failed: Bool { !failures.isEmpty }
}

enum DisplayPresetSupport {
    static let maximumPresets = 24
    /// A preset's icon is one of a small set, so imported JSON cannot put an
    /// arbitrary name into an image lookup.
    static let symbols = ["display", "display.2", "laptopcomputer", "desktopcomputer",
                          "rectangle.on.rectangle", "house", "building.2", "briefcase",
                          "sun.max", "moon.stars", "gamecontroller", "camera"]
    static let defaultSymbol = "display"
    /// The same display reporting no usable identity as in display
    /// restoration: an all-zero fingerprint, a broadcast serial, or the
    /// "unknown" vendor.
    private static let unusableFingerprints: Set<String> = ["0:0:0"]

    // MARK: - Identity

    static func fingerprint(vendor: UInt32, model: UInt32, serial: UInt32) -> String? {
        let value = "\(vendor):\(model):\(serial)"
        return isUsable(value) ? value : nil
    }

    static func isUsable(_ fingerprint: String) -> Bool {
        guard !fingerprint.isEmpty, !unusableFingerprints.contains(fingerprint),
              !fingerprint.contains(String(UInt32.max)),
              !fingerprint.hasPrefix("\(0x756E6B6E):")
        else { return false }
        let parts = fingerprint.split(separator: ":")
        return parts.count == 3 && parts.allSatisfy { UInt32($0) != nil }
    }

    static func fingerprint(of display: CGDirectDisplayID) -> String? {
        fingerprint(vendor: CGDisplayVendorNumber(display),
                    model: CGDisplayModelNumber(display),
                    serial: CGDisplaySerialNumber(display))
    }

    // MARK: - Stored form

    static func decode(_ data: Data?) -> [DisplayPreset] {
        guard let data, !data.isEmpty,
              let decoded = try? JSONDecoder().decode([DisplayPreset].self, from: data)
        else { return [] }
        var seen = Set<UUID>()
        return decoded.compactMap(sanitized).filter { preset in
            seen.insert(preset.id).inserted
        }.prefix(maximumPresets).map { $0 }
    }

    static func encode(_ presets: [DisplayPreset]) -> Data {
        (try? JSONEncoder().encode(presets)) ?? Data()
    }

    static func sanitized(_ preset: DisplayPreset) -> DisplayPreset? {
        let name = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displays = preset.displays.prefix(maximumPresets).compactMap(sanitized)
        guard !name.isEmpty, !displays.isEmpty else { return nil }
        var result = preset
        result.name = String(name.prefix(80))
        result.symbol = symbols.contains(preset.symbol) ? preset.symbol : defaultSymbol
        result.displays = Array(displays)
        let fingerprints = Set(result.displays.map(\.fingerprint))
        if let main = result.mainDisplayFingerprint, !fingerprints.contains(main) {
            result.mainDisplayFingerprint = nil
        }
        if let shortcut = result.shortcut, GlobalShortcut(storageValue: shortcut) == nil {
            result.shortcut = nil
        }
        if let trigger = result.trigger {
            let triggerName = trigger.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if isUsable(trigger.fingerprint), !triggerName.isEmpty {
                result.trigger = trigger
            } else {
                result.trigger = nil
            }
        }
        return result
    }

    private static func sanitized(_ display: DisplayPreset.Display) -> DisplayPreset.Display? {
        guard isUsable(display.fingerprint) else { return nil }
        var result = display
        result.name = String(display.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        // A corrupted resolution drops that item, never the display: its
        // brightness and its place in the arrangement are still good.
        if let resolution = display.resolution {
            if resolution.width > 0, resolution.height > 0,
               resolution.pixelWidth > 0, resolution.pixelHeight > 0,
               resolution.refreshRate.isFinite, resolution.refreshRate >= 0 {
                var cleaned = resolution
                cleaned.refreshRate = min(cleaned.refreshRate, 1_000)
                result.resolution = cleaned
            } else {
                result.resolution = nil
            }
        }
        result.brightness = sanitizedLevel(display.brightness)
        result.volume = sanitizedLevel(display.volume)
        return result
    }

    private static func sanitizedLevel(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return min(max(value, 0), 1)
    }

    // MARK: - Matching

    /// The live display a saved entry belongs to. Identity first; the built-in
    /// panel falls back to the only built-in display, and identical external
    /// monitors fall back to snapshot order.
    static func match(_ entry: DisplayPreset.Display,
                      among displays: [(id: CGDirectDisplayID, fingerprint: String?, isBuiltIn: Bool)],
                      used: inout Set<CGDirectDisplayID>) -> CGDirectDisplayID? {
        if let exact = displays.first(where: {
            $0.fingerprint == entry.fingerprint && !used.contains($0.id)
        }) {
            used.insert(exact.id)
            return exact.id
        }
        if entry.isBuiltIn, let builtIn = displays.first(where: {
            $0.isBuiltIn && !used.contains($0.id)
        }) {
            used.insert(builtIn.id)
            return builtIn.id
        }
        if let sameModel = displays.first(where: {
            sameHardware($0.fingerprint, entry.fingerprint) && !used.contains($0.id)
        }) {
            used.insert(sameModel.id)
            return sameModel.id
        }
        return nil
    }

    /// Two connections of the same monitor model are the same hardware even
    /// when their serial numbers are not reported.
    static func sameHardware(_ lhs: String?, _ rhs: String) -> Bool {
        guard let lhs else { return false }
        let left = lhs.split(separator: ":").prefix(2)
        let right = rhs.split(separator: ":").prefix(2)
        return !left.isEmpty && left == right
    }

    static func currentResolution(of mode: CGDisplayMode) -> DisplayPreset.Resolution {
        DisplayPreset.Resolution(width: mode.width,
                                 height: mode.height,
                                 pixelWidth: mode.pixelWidth,
                                 pixelHeight: mode.pixelHeight,
                                 refreshRate: normalizedRefresh(mode.refreshRate))
    }

    /// Some modes report no refresh rate; keep the UI and JSON from carrying
    /// a negative placeholder.
    static func normalizedRefresh(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else { return 0 }
        return (value * 100).rounded() / 100
    }

    /// Index of the supported mode that reproduces the saved one. Logical and
    /// backing sizes must match exactly, because a non-Retina mode with the
    /// same logical size is a different setting. Refresh rate picks between
    /// otherwise identical modes, and a missing rate is not a reason to refuse.
    static func bestModeIndex(for saved: DisplayPreset.Resolution,
                              in candidates: [DisplayPreset.Resolution]) -> Int? {
        let sizeMatches = candidates.indices.filter { index in
            let candidate = candidates[index]
            return candidate.width == saved.width && candidate.height == saved.height
                && candidate.pixelWidth == saved.pixelWidth
                && candidate.pixelHeight == saved.pixelHeight
        }
        guard !sizeMatches.isEmpty else { return nil }
        guard saved.refreshRate > 0 else { return sizeMatches.first }
        return sizeMatches.min { lhs, rhs in
            abs(candidates[lhs].refreshRate - saved.refreshRate)
                < abs(candidates[rhs].refreshRate - saved.refreshRate)
        }
    }

    static func sameResolution(_ lhs: DisplayPreset.Resolution?,
                               _ rhs: DisplayPreset.Resolution?) -> Bool {
        guard let lhs, let rhs else { return lhs == nil && rhs == nil }
        return lhs.width == rhs.width && lhs.height == rhs.height
            && lhs.pixelWidth == rhs.pixelWidth && lhs.pixelHeight == rhs.pixelHeight
            && abs(lhs.refreshRate - rhs.refreshRate) <= 0.5
    }

    // MARK: - Automatic rules

    static func changedFingerprints(previous: Set<String>,
                                    current: Set<String>) -> (added: Set<String>, removed: Set<String>) {
        (current.subtracting(previous), previous.subtracting(current))
    }

    /// Presets are consulted in list order; the first rule that matches the
    /// change wins, so two rules for one display never fight over a change.
    static func presetToApply(_ presets: [DisplayPreset],
                              added: Set<String>, removed: Set<String>) -> DisplayPreset? {
        presets.first { preset in
            guard let trigger = preset.trigger else { return false }
            switch trigger.event {
            case .connected: return added.contains(trigger.fingerprint)
            case .disconnected: return removed.contains(trigger.fingerprint)
            }
        }
    }

    // MARK: - Hostnames and labels

    static func displayLabel(_ display: DisplayPreset.Display) -> String {
        display.name.isEmpty ? display.fingerprint : display.name
    }

    static func triggerEventRank(_ event: DisplayPreset.Trigger.Event) -> Int {
        event == .connected ? 0 : 1
    }
}
