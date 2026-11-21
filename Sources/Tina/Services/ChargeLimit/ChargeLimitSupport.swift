// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// One battery reading, as the charge limit needs it. Kept as a value so the
/// policy below can be pinned without a battery, an SMC key or a helper.
struct ChargeLimitBatteryReading: Equatable {
    var percent: Int
    var isCharging: Bool
    var isPluggedIn: Bool
    var isFullyCharged: Bool
    var hasBattery: Bool

    static let none = ChargeLimitBatteryReading(percent: 0, isCharging: false,
                                                isPluggedIn: false, isFullyCharged: false,
                                                hasBattery: false)
}

/// The SMC keys that stop charging on Apple Silicon MacBooks, in the order the
/// investigation found them. `batt` documents the same two families: the
/// single Tahoe-era state key, and the older pair of per-charger flags.
///
/// Only the key layout is encoded here. Nothing in this type can write a key.
enum ChargeControlKeySet: String, Codable, Equatable {
    /// `CHTE`, a ui32 whose first byte is 1 while charging is inhibited.
    case chargingState = "CHTE"
    /// `CH0B` and `CH0C`, one ui8 each: 0 enables charging, 2 inhibits it.
    case chargingFlags = "CH0B+CH0C"

    static func detect(hasKey: (String) -> Bool) -> ChargeControlKeySet? {
        if hasKey("CHTE") { return .chargingState }
        if hasKey("CH0B") && hasKey("CH0C") { return .chargingFlags }
        return nil
    }

    var keyNames: [String] {
        switch self {
        case .chargingState: return ["CHTE"]
        case .chargingFlags: return ["CH0B", "CH0C"]
        }
    }

    /// Raw SMC payload per key, in write order. These keys report state as
    /// bytes rather than a scaled number, so the client writes them with
    /// `writeBytes` and reads the same bytes back for verification.
    func payload(inhibit: Bool) -> [(key: String, bytes: [UInt8])] {
        switch self {
        case .chargingState:
            return [("CHTE", inhibit ? [0x01, 0x00, 0x00, 0x00] : [0x00, 0x00, 0x00, 0x00])]
        case .chargingFlags:
            let byte: UInt8 = inhibit ? 0x02 : 0x00
            // The pair is written in the order `batt` uses; the first key
            // gates the second.
            return [("CH0B", [byte]), ("CH0C", [byte])]
        }
    }

    /// `nil` when the bytes are not a state this model understands, so an
    /// unknown value is never mistaken for "charging allowed" and overwritten.
    func isInhibited(_ bytes: [UInt8]) -> Bool? {
        switch self {
        case .chargingState:
            guard bytes.count == 4 else { return nil }
            return bytes.contains { $0 != 0 }
        case .chargingFlags:
            guard bytes.count == 1 else { return nil }
            switch bytes[0] {
            case 0x00: return false
            case 0x02: return true
            default: return nil
            }
        }
    }
}

/// The whole user-visible policy of the charge limit. The helper runs it on
/// every tick; the app uses the same functions to describe what will happen, so
/// the card and the hardware can never disagree about the thresholds.
enum ChargeLimitPolicy {
    static let minimumPercent = 60
    static let maximumPercent = 100
    static let defaultPercent = 80
    /// Charging must fall this far below the upper limit before it resumes, so
    /// a Mac sitting at the limit does not toggle the SMC key on every tick.
    static let hysteresisPercent = 5

    static func sanitizedPercent(_ percent: Int) -> Int {
        min(maximumPercent, max(minimumPercent, percent))
    }

    static func lowerBound(forUpper upperPercent: Int) -> Int {
        max(minimumPercent, sanitizedPercent(upperPercent) - hysteresisPercent)
    }

    enum Decision: Equatable {
        case allowCharging
        case inhibitCharging
        /// The current state is already the safe one; write nothing.
        case hold
    }

    /// `chargeToFull` is a one-shot request that wins over the limit until the
    /// battery reports full. `isInhibited` is read back from hardware rather
    /// than remembered, so a helper restart cannot invert the hysteresis.
    static func decision(percent: Int, upperPercent: Int, isInhibited: Bool,
                         chargeToFull: Bool) -> Decision {
        let upper = sanitizedPercent(upperPercent)
        if chargeToFull { return isInhibited ? .allowCharging : .hold }
        if percent >= upper { return isInhibited ? .hold : .inhibitCharging }
        if percent <= lowerBound(forUpper: upper) {
            return isInhibited ? .allowCharging : .hold
        }
        return .hold
    }

    /// "Charge to full once" ends at full, or at 100% when the battery no
    /// longer reports a separate charged flag.
    static func fullChargeRequestIsDone(percent: Int, isFullyCharged: Bool) -> Bool {
        isFullyCharged || percent >= 100
    }
}
