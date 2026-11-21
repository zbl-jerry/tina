// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation
import IOKit
import IOKit.ps

/// Reads the battery and owns the only SMC write this feature can perform:
/// the charging-inhibit state, in the two layouts Apple Silicon MacBooks
/// expose. There is no arbitrary key or byte entry point.
final class ChargeLimitHardware {
    enum HardwareError: Error {
        case unsupported
        case verificationFailed
    }

    struct Reading {
        let battery: ChargeLimitBatteryReading
        /// One entry per key in the set, in `keyNames` order.
        let inhibitedStates: [Bool]

        var isInhibited: Bool { inhibitedStates.contains(true) }
        var agrees: Bool { inhibitedStates.allSatisfy { $0 == inhibitedStates.first } }
    }

    private let client: SMCClient
    private let variant: ChargeControlKeySet
    private let keys: [String: SMCClient.Key]

    init?() {
        guard let client = SMCClient() else { return nil }
        guard let variant = ChargeControlKeySet.detect(hasKey: { client.key(named: $0) != nil })
        else { return nil }
        var keys: [String: SMCClient.Key] = [:]
        for name in variant.keyNames {
            guard let key = client.key(named: name) else { return nil }
            keys[name] = key
        }
        self.client = client
        self.variant = variant
        self.keys = keys
    }

    /// A read-only answer for the feature catalog and the card's unsupported
    /// state. Cost is one AppleSMC open per process.
    static let hasChargeControl: Bool = ChargeLimitHardware() != nil

    var keySet: ChargeControlKeySet { variant }

    // MARK: - Reads

    func read() throws -> Reading {
        var states: [Bool] = []
        for name in variant.keyNames {
            guard let key = keys[name], let bytes = client.readBytes(key),
                  let state = variant.isInhibited(bytes) else {
                throw HardwareError.unsupported
            }
            states.append(state)
        }
        return Reading(battery: Self.readBattery(), inhibitedStates: states)
    }

    /// Reads the same public power-source fields the system monitor uses.
    static func readBattery() -> ChargeLimitBatteryReading {
        if let reading = ioPowerSourcesBattery() { return reading }
        return registryBattery()
    }

    private static func ioPowerSourcesBattery() -> ChargeLimitBatteryReading? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() else { return nil }
        for source in list as [CFTypeRef] {
            guard let description = IOPSGetPowerSourceDescription(info, source)?
                    .takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == "InternalBattery" else { continue }
            if let reading = reading(percent: percent(current: description[kIOPSCurrentCapacityKey],
                                                     maximum: description[kIOPSMaxCapacityKey]),
                                     pluggedIn: description[kIOPSPowerSourceStateKey] as? String
                                         == kIOPSACPowerValue,
                                     isCharging: (description[kIOPSIsChargingKey] as? Bool) ?? false,
                                     isFullyCharged: (description[kIOPSIsChargedKey] as? Bool) ?? false) {
                return reading
            }
        }
        return nil
    }

    private static func registryBattery() -> ChargeLimitBatteryReading {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return .none }
        defer { IOObjectRelease(service) }
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
                == kIOReturnSuccess,
              let dict = properties?.takeRetainedValue() as? [String: Any] else { return .none }
        guard (dict["BatteryInstalled"] as? Bool) != false else { return .none }
        return reading(percent: percent(current: dict["CurrentCapacity"],
                                        maximum: dict["MaxCapacity"]),
                       pluggedIn: (dict["ExternalConnected"] as? Bool) ?? false,
                       isCharging: (dict["IsCharging"] as? Bool) ?? false,
                       isFullyCharged: (dict["IsCharged"] as? Bool) ?? false) ?? .none
    }

    private static func reading(percent: Int?, pluggedIn: Bool,
                                isCharging: Bool, isFullyCharged: Bool)
        -> ChargeLimitBatteryReading? {
        guard let percent else { return nil }
        return ChargeLimitBatteryReading(percent: percent,
                                         isCharging: isCharging,
                                         isPluggedIn: pluggedIn,
                                         isFullyCharged: isFullyCharged,
                                         hasBattery: true)
    }

    private static func percent(current: Any?, maximum: Any?) -> Int? {
        guard let current = intValue(current) else { return nil }
        let maximum = intValue(maximum) ?? 100
        guard maximum > 0, current >= 0 else { return nil }
        if maximum == 100 { return min(100, current) }
        return min(100, max(0, Int((Double(current) / Double(maximum) * 100).rounded())))
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let value as Int: return value
        case let value as NSNumber: return value.intValue
        case let value as String: return Int(value)
        default: return nil
        }
    }

    // MARK: - Write

    /// Writes the inhibit state and verifies it by reading every key back. On a
    /// mismatch the caller is expected to put charging back immediately.
    func setInhibited(_ inhibit: Bool) throws {
        for step in variant.payload(inhibit: inhibit) {
            guard let key = keys[step.key] else { throw HardwareError.unsupported }
            try client.writeBytes(step.bytes, to: key)
        }
        // The controller polls rarely; this sleep is bounded and runs on the
        // helper's serial queue, never on a UI thread.
        Thread.sleep(forTimeInterval: 0.05)
        do {
            guard try read().inhibitedStates.allSatisfy({ $0 == inhibit }) else {
                throw HardwareError.verificationFailed
            }
        } catch {
            // A write we cannot confirm is a failed write: the caller undoes
            // it rather than leaving an unchecked inhibit behind.
            throw HardwareError.verificationFailed
        }
    }
}
