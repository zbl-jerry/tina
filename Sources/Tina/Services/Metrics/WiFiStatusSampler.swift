// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import CoreWLAN
import Foundation
import SystemConfiguration

/// Reads the Wi-Fi token's state with public APIs only. CoreWLAN answers for
/// the radio; SystemConfiguration names the primary route, which is how an
/// Ethernet connection is told apart from an unassociated radio without ever
/// asking for the SSID (that read is gated behind Location Services).
struct WiFiStatusSampler {
    func sample() -> WiFiStatusReading {
        let interface = CWWiFiClient.shared().interface()
        return WiFiStateResolver.reading(wifiInterfaceName: interface?.interfaceName,
                                         isPoweredOn: interface?.powerOn(),
                                         primaryInterfaceName: Self.primaryInterfaceName(),
                                         rssi: interface?.rssiValue())
    }

    /// The interface currently carrying the default IPv4 route, if any.
    private static func primaryInterfaceName() -> String? {
        guard let store = SCDynamicStoreCreate(nil,
                                               "com.tina.wifi-status" as CFString,
                                               nil,
                                               nil),
              let value = SCDynamicStoreCopyValue(store,
                                                  "State:/Network/Global/IPv4" as CFString),
              let dictionary = value as? [String: Any]
        else { return nil }
        return dictionary[kSCDynamicStorePropNetPrimaryInterface as String] as? String
    }
}
