// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// What the Wi-Fi menu bar token reports. `ethernet` is an active non-Wi-Fi
/// primary route, so a Mac whose radio is off but has a cable in still says it
/// is online; `unavailable` means the state could not be read at all and is
/// never folded into "not connected".
enum WiFiLinkState: Equatable {
    case connected
    case notConnected
    case ethernet
    case poweredOff
    case unavailable
}

struct WiFiStatusReading: Equatable {
    var state: WiFiLinkState
    /// Signal strength in dBm; nil when the Mac is not on Wi-Fi or the reading
    /// failed. Not an SSID: the token never shows network names.
    var rssi: Int?

    static let unavailable = WiFiStatusReading(state: .unavailable, rssi: nil)
}

/// The default output's volume and mute switch. A nil part is a reading this
/// output cannot answer, never a zero: the token says so instead of pretending
/// the Mac is at 0%.
struct OutputVolumeReading: Equatable {
    /// 0...1 as reported by the output's main scalar.
    var level: Double?
    /// nil when the output has no mute switch of its own.
    var isMuted: Bool?
}

/// Resolves the Wi-Fi token from readings the live sampler provides. Kept free
/// of CoreWLAN and SystemConfiguration so every fallback is testable.
enum WiFiStateResolver {
    static func reading(wifiInterfaceName: String?,
                        isPoweredOn: Bool?,
                        primaryInterfaceName: String?,
                        rssi: Int?) -> WiFiStatusReading {
        if let primary = primaryInterfaceName, !primary.isEmpty {
            if let wifi = wifiInterfaceName, primary == wifi {
                // CoreWLAN reports 0 for "not associated"; only a negative dBm
                // reading is real signal strength.
                let signal = rssi.flatMap { $0 < 0 ? $0 : nil }
                return WiFiStatusReading(state: .connected, rssi: signal)
            }
            return WiFiStatusReading(state: .ethernet, rssi: nil)
        }
        guard wifiInterfaceName != nil else { return .unavailable }
        switch isPoweredOn {
        case .some(false): return WiFiStatusReading(state: .poweredOff, rssi: nil)
        case .some(true): return WiFiStatusReading(state: .notConnected, rssi: nil)
        case .none: return .unavailable
        }
    }
}

/// The compact text of the Wi-Fi token. Connection states are wordless
/// abbreviations in the same spirit as CPU/RAM/BAT; the unavailable state is
/// deliberately distinct from "not connected".
enum WiFiStatusText {
    static let label = "WIFI"
    static let unavailableValue = "N/A"
    static let minimumValue = "100%"

    static func value(for reading: WiFiStatusReading?, showsSignal: Bool) -> String {
        guard let reading else { return unavailableValue }
        switch reading.state {
        case .connected:
            guard showsSignal, let rssi = reading.rssi else { return "ON" }
            return "\(quality(rssi: rssi))%"
        case .notConnected: return "--"
        case .ethernet: return "LAN"
        case .poweredOff: return "OFF"
        case .unavailable: return unavailableValue
        }
    }

    /// 0...100 from dBm: -100 dBm is unusable and -50 dBm or better is full,
    /// the mapping menu bar utilities commonly use.
    static func quality(rssi: Int) -> Int {
        max(0, min(100, (rssi + 100) * 2))
    }
}

/// The compact text of the output volume token.
enum OutputVolumeText {
    static let label = "VOL"
    static let unavailableValue = "N/A"
    static let mutedValue = "MUTE"
    static let minimumValue = "100%"

    static func value(for reading: OutputVolumeReading?) -> String {
        guard let reading else { return unavailableValue }
        if reading.isMuted == true { return mutedValue }
        guard let level = reading.level else { return unavailableValue }
        let clamped = max(0, min(1, level))
        return "\(Int((clamped * 100).rounded()))%"
    }
}
