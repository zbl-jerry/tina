// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// What the app asks the helper to hold. The upper limit travels with every
/// request so a stale request can never keep a limit the user has moved away
/// from; `chargeToFull` is a one-shot that the helper clears itself.
struct ChargeLimitConfiguration: Codable, Equatable {
    var upperPercent: Int
    var chargeToFull: Bool = false
}

enum ChargeLimitErrorCode: String, Codable, Equatable {
    case unsupportedHardware
    case controlFailed
    case verificationFailed
    case alreadyControlled
}

/// Everything the card needs to describe the Mac. Read-only fields are filled
/// by the helper; `upperPercent` and `chargeToFull` echo the active request.
struct ChargeLimitStatus: Codable, Equatable {
    var variant: ChargeControlKeySet?
    var percent: Int?
    var isCharging = false
    var isPluggedIn = false
    var isFullyCharged = false
    var isInhibited = false
    var upperPercent: Int?
    var chargeToFull = false
    var error: ChargeLimitErrorCode?

    var isSupported: Bool { variant != nil && percent != nil }

    static let empty = ChargeLimitStatus()
}

struct ChargeLimitResponse: Codable, Equatable {
    var succeeded: Bool
    var status: ChargeLimitStatus
    var error: ChargeLimitErrorCode?

    static func success(_ status: ChargeLimitStatus) -> ChargeLimitResponse {
        ChargeLimitResponse(succeeded: true, status: status, error: nil)
    }

    static func failure(_ error: ChargeLimitErrorCode,
                        status: ChargeLimitStatus = .empty) -> ChargeLimitResponse {
        ChargeLimitResponse(succeeded: false, status: status, error: error)
    }
}

enum ChargeLimitIPC {
    static func encode(_ response: ChargeLimitResponse) -> Data {
        // A closed response model with one deterministic fallback, matching the
        // fan helper's reply contract.
        (try? JSONEncoder().encode(response))
            ?? Data(#"{"succeeded":false,"status":{},"error":"controlFailed"}"#.utf8)
    }

    static func decode(_ data: Data) -> ChargeLimitResponse? {
        try? JSONDecoder().decode(ChargeLimitResponse.self, from: data)
    }

    static func encode(_ configuration: ChargeLimitConfiguration) -> Data? {
        try? JSONEncoder().encode(configuration)
    }

    static func decodeConfiguration(_ data: Data) -> ChargeLimitConfiguration? {
        guard let configuration = try? JSONDecoder().decode(ChargeLimitConfiguration.self,
                                                              from: data),
              configuration.upperPercent >= ChargeLimitPolicy.minimumPercent,
              configuration.upperPercent <= ChargeLimitPolicy.maximumPercent else { return nil }
        return configuration
    }
}
