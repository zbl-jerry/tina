// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import CoreWLAN
import Foundation
import SystemConfiguration

/// Reads link evidence from CoreWLAN and both primary routes from
/// SystemConfiguration without asking for the SSID.
struct WiFiStatusSampler {
    func sample() -> WiFiStatusReading {
        let interface = CWWiFiClient.shared().interface()
        let routes = Self.primaryInterfaces()
        let ethernet = routes.isEmpty ? [] : Self.ethernetInterfaces()
        return WiFiStateResolver.reading(wifiInterfaceName: interface?.interfaceName,
                                         isPoweredOn: interface?.powerOn(),
                                         primaryInterfaces: routes,
                                         ethernetInterfaces: ethernet,
                                         rssi: interface?.rssiValue())
    }

    private static func primaryInterfaces() -> Set<String> {
        guard let store = SCDynamicStoreCreate(nil,
                                               "com.tina.wifi-status" as CFString,
                                               nil,
                                               nil) else { return [] }
        return Set(["IPv4", "IPv6"].compactMap { family in
            let value = SCDynamicStoreCopyValue(store, "State:/Network/Global/\(family)" as CFString)
            return (value as? [String: Any])?[kSCDynamicStorePropNetPrimaryInterface as String] as? String
        })
    }

    private static func ethernetInterfaces() -> Set<String> {
        guard let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else { return [] }
        return Set(interfaces.compactMap { interface in
            guard SCNetworkInterfaceGetInterfaceType(interface) == kSCNetworkInterfaceTypeEthernet else {
                return nil
            }
            return SCNetworkInterfaceGetBSDName(interface) as String?
        })
    }
}
