// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// The charge limit's decisions and SMC payloads are pure, so they are pinned
/// here without a battery, a helper or a root process.
enum ChargeLimitTests {
    static func run(_ suite: TestSuite) {
        // MARK: Percent and hysteresis

        suite.expect(ChargeLimitPolicy.sanitizedPercent(10) == 60,
                     "a limit below the supported range clamps to 60%")
        suite.expect(ChargeLimitPolicy.sanitizedPercent(120) == 100,
                     "a limit above 100% clamps to 100")
        suite.expect(ChargeLimitPolicy.sanitizedPercent(83) == 83,
                     "a supported limit is kept")
        suite.expect(ChargeLimitPolicy.lowerBound(forUpper: 80) == 75,
                     "80% resumes at 75%")
        suite.expect(ChargeLimitPolicy.lowerBound(forUpper: 60) == 60,
                     "the lower bound never falls below the supported range")
        suite.expect(ChargeLimitPolicy.lowerBound(forUpper: 100) == 95,
                     "100% resumes at 95%")

        // MARK: Decisions

        suite.expect(ChargeLimitPolicy.decision(percent: 80, upperPercent: 80,
                                                isInhibited: false,
                                                chargeToFull: false) == .inhibitCharging,
                     "at the limit, a charging Mac is inhibited")
        suite.expect(ChargeLimitPolicy.decision(percent: 80, upperPercent: 80,
                                                isInhibited: true,
                                                chargeToFull: false) == .hold,
                     "holding at the limit writes nothing")
        suite.expect(ChargeLimitPolicy.decision(percent: 77, upperPercent: 80,
                                                isInhibited: true,
                                                chargeToFull: false) == .hold,
                     "inside the hysteresis band an inhibited Mac stays inhibited")
        suite.expect(ChargeLimitPolicy.decision(percent: 77, upperPercent: 80,
                                                isInhibited: false,
                                                chargeToFull: false) == .hold,
                     "inside the hysteresis band a charging Mac keeps charging")
        suite.expect(ChargeLimitPolicy.decision(percent: 75, upperPercent: 80,
                                                isInhibited: true,
                                                chargeToFull: false) == .allowCharging,
                     "at the lower bound, charging resumes")
        suite.expect(ChargeLimitPolicy.decision(percent: 74, upperPercent: 80,
                                                isInhibited: false,
                                                chargeToFull: false) == .hold,
                     "below the bound, an already charging Mac writes nothing")
        suite.expect(ChargeLimitPolicy.decision(percent: 79, upperPercent: 100,
                                                isInhibited: false,
                                                chargeToFull: false) == .hold,
                     "a 100% limit leaves an uncharged Mac alone")
        suite.expect(ChargeLimitPolicy.decision(percent: 100, upperPercent: 100,
                                                isInhibited: false,
                                                chargeToFull: false) == .inhibitCharging,
                     "a 100% limit still stops a full charge")

        // MARK: Charge to full once

        suite.expect(ChargeLimitPolicy.decision(percent: 80, upperPercent: 80,
                                                isInhibited: true,
                                                chargeToFull: true) == .allowCharging,
                     "charge-to-full releases an inhibited Mac")
        suite.expect(ChargeLimitPolicy.decision(percent: 80, upperPercent: 80,
                                                isInhibited: false,
                                                chargeToFull: true) == .hold,
                     "charge-to-full does not write while charging")
        suite.expect(!ChargeLimitPolicy.fullChargeRequestIsDone(percent: 99,
                                                                isFullyCharged: false),
                     "the one-shot lasts until full")
        suite.expect(ChargeLimitPolicy.fullChargeRequestIsDone(percent: 100,
                                                               isFullyCharged: false),
                     "100% ends the one-shot")
        suite.expect(ChargeLimitPolicy.fullChargeRequestIsDone(percent: 80,
                                                               isFullyCharged: true),
                     "the system's charged flag ends the one-shot")

        // MARK: Key detection and payloads

        suite.expect(ChargeControlKeySet.detect { $0 == "CHTE" } == .chargingState,
                     "CHTE is preferred when present")
        suite.expect(ChargeControlKeySet.detect { $0 == "CH0B" || $0 == "CH0C" } == .chargingFlags,
                     "the older pair is used when CHTE is missing")
        suite.expect(ChargeControlKeySet.detect { $0 == "CH0B" } == nil,
                     "half of the older pair is not a control")
        suite.expect(ChargeControlKeySet.detect { _ in false } == nil,
                     "a Mac with neither layout has no charge control")

        let stateInhibit = ChargeControlKeySet.chargingState.payload(inhibit: true)
        suite.expect(stateInhibit.count == 1 && stateInhibit[0].key == "CHTE"
                        && stateInhibit[0].bytes == [0x01, 0x00, 0x00, 0x00],
                     "CHTE inhibits with a 1 in its first byte")
        let stateAllow = ChargeControlKeySet.chargingState.payload(inhibit: false)
        suite.expect(stateAllow.count == 1 && stateAllow[0].bytes == [0x00, 0x00, 0x00, 0x00],
                     "CHTE allows with all zeros")
        let pairInhibit = ChargeControlKeySet.chargingFlags.payload(inhibit: true)
        suite.expect(pairInhibit.map(\.key) == ["CH0B", "CH0C"]
                        && pairInhibit.allSatisfy { $0.bytes == [0x02] },
                     "the pair inhibits with 2, first key first")
        let pairAllow = ChargeControlKeySet.chargingFlags.payload(inhibit: false)
        suite.expect(pairAllow.allSatisfy { $0.bytes == [0x00] },
                     "the pair allows with 0")

        suite.expect(ChargeControlKeySet.chargingState.isInhibited([0x01, 0, 0, 0]) == true,
                     "a non-zero CHTE state reads as inhibited")
        suite.expect(ChargeControlKeySet.chargingState.isInhibited([0, 0, 0, 0]) == false,
                     "an all-zero CHTE state reads as charging allowed")
        suite.expect(ChargeControlKeySet.chargingState.isInhibited([0, 0]) == nil,
                     "a CHTE value of the wrong length is unknown")
        suite.expect(ChargeControlKeySet.chargingFlags.isInhibited([0x02]) == true,
                     "0x02 reads as inhibited")
        suite.expect(ChargeControlKeySet.chargingFlags.isInhibited([0x00]) == false,
                     "0x00 reads as charging allowed")
        suite.expect(ChargeControlKeySet.chargingFlags.isInhibited([0x07]) == nil,
                     "an unrecognised flag is never guessed")

        // MARK: IPC validation

        let accepted = ChargeLimitIPC.decodeConfiguration(
            try! JSONEncoder().encode(ChargeLimitConfiguration(upperPercent: 80)))
        suite.expect(accepted?.upperPercent == 80, "a supported configuration decodes")
        for invalid in [59, 101] {
            let decoded = ChargeLimitIPC.decodeConfiguration(
                try! JSONEncoder().encode(ChargeLimitConfiguration(upperPercent: invalid)))
            suite.expect(decoded == nil, "a limit outside 60-100 is rejected (\(invalid))")
        }

        let response = ChargeLimitIPC.decode(ChargeLimitIPC.encode(
            .failure(.unsupportedHardware, status: .empty)))
        suite.expect(response?.succeeded == false && response?.error == .unsupportedHardware,
                     "a failure reply round-trips")
    }
}
