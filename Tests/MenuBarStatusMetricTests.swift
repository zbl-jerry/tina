// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// The menu bar's Wi-Fi and output-volume tokens: saved order, sampling
/// cadence, unavailable fallbacks and compact text for every state.
enum MenuBarStatusMetricTests {
    static func run(_ suite: TestSuite) {
        let domain = "com.tina.tests.menu-bar-status"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }

        orderContracts(suite, defaults: defaults)
        cadenceContracts(suite)
        wifiStateContracts(suite)
        wifiTextContracts(suite)
        volumeTextContracts(suite)
    }

    // MARK: - Saved order

    private static func orderContracts(_ suite: TestSuite, defaults: UserDefaults) {
        let order = Defaults.defaultMenuBarMetricOrder
        suite.expect(order.contains("wifi") && order.contains("volume"),
                     "the default metric order includes the Wi-Fi and volume tokens")
        suite.expect(Set(order).count == order.count,
                     "the default metric order lists every token once")
        suite.expect(Defaults.sanitizedMenuBarMetricOrder(order.joined(separator: ",")) == order,
                     "a saved order containing both tokens round-trips unchanged")
        suite.expect(Defaults.sanitizedMenuBarMetricOrder("wifi,volume,wifi,bad,cpu")
                     == ["wifi", "volume", "cpu", "cpuTemperature", "gpu", "gpuTemperature", "memory",
                         "battery", "batteryTime", "batteryTemperature", "peripheralBattery", "network",
                         "diskUsage", "diskActivity", "connectedDevices", "power", "fanSpeed"],
                     "new tokens are kept once, unknown values are dropped, and missing tokens are appended")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.menuBarMetricOrder] as? String
                     == order.joined(separator: ","),
                     "the registered order matches the shipped token list")
        suite.expect((Defaults.registeredDefaults[DefaultsKey.menuBarWiFi] as? Bool) == false
                     && (Defaults.registeredDefaults[DefaultsKey.menuBarVolume] as? Bool) == false
                     && (Defaults.registeredDefaults[DefaultsKey.menuBarWiFiSignal] as? Bool) == false,
                     "both tokens and the signal option are opt-in and participate in settings backup")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.menuBarWiFi] != nil
                     && Defaults.registeredDefaults[DefaultsKey.menuBarVolume] != nil,
                     "the new preference keys carry registered defaults")
        defaults.set(true, forKey: DefaultsKey.menuBarWiFi)
        defaults.set(true, forKey: DefaultsKey.menuBarVolume)
        defaults.set(true, forKey: DefaultsKey.menuBarWiFiSignal)
        suite.expect(defaults.bool(forKey: DefaultsKey.menuBarWiFi)
                     && defaults.bool(forKey: DefaultsKey.menuBarVolume)
                     && defaults.bool(forKey: DefaultsKey.menuBarWiFiSignal),
                     "the isolated defaults domain stores the token switches")
    }

    // MARK: - Sampling cadence

    private static func cadenceContracts(_ suite: TestSuite) {
        suite.expect(MonitorSamplingPolicy.sampleStride(for: .wifi,
                                                        intervalSeconds: 2,
                                                        foreground: false) == 8,
                     "Wi-Fi reads about every 15 s at the default 2 s tick")
        suite.expect(MonitorSamplingPolicy.sampleStride(for: .wifi,
                                                        intervalSeconds: 2,
                                                        foreground: true) == 8,
                     "a visible panel does not make the Wi-Fi daemon query every tick")
        suite.expect(MonitorSamplingPolicy.shouldSample(.wifi,
                                                        tick: 8,
                                                        intervalSeconds: 2,
                                                        foreground: false)
                     && !MonitorSamplingPolicy.shouldSample(.wifi,
                                                            tick: 7,
                                                            intervalSeconds: 2,
                                                            foreground: false),
                     "the Wi-Fi sampler wakes only on its stride")
        suite.expect(MonitorSamplingPolicy.sampleStride(for: .volume,
                                                        intervalSeconds: 2,
                                                        foreground: false) == 1,
                     "volume follows the monitor's normal cadence")
        suite.expect(MonitorSamplingPolicy.sampleStride(for: .volume,
                                                        intervalSeconds: 2,
                                                        foreground: true) == 1,
                     "volume is read on every foreground tick")
    }

    // MARK: - Wi-Fi state

    private static func wifiStateContracts(_ suite: TestSuite) {
        func reading(_ wifi: String?, power: Bool?, routes: Set<String>, rssi: Int? = nil) -> WiFiStatusReading {
            WiFiStateResolver.reading(wifiInterfaceName: wifi,
                                      isPoweredOn: power,
                                      primaryInterfaces: routes,
                                      ethernetInterfaces: ["en5"],
                                      rssi: rssi)
        }

        suite.expect(reading("en0", power: true, routes: ["en0"], rssi: -52)
                     == WiFiStatusReading(state: .connected, rssi: -52),
                     "the Wi-Fi interface carrying the primary route is connected with its signal")
        suite.expect(reading("en0", power: true, routes: ["en0"], rssi: 0)
                     == WiFiStatusReading(state: .connected, rssi: nil),
                     "CoreWLAN's zero RSSI is not a signal strength")
        suite.expect(reading("en0", power: true, routes: ["en5"]) == WiFiStatusReading(state: .ethernet, rssi: nil),
                     "a typed Ethernet primary interface is reported as Ethernet")
        suite.expect(reading("en0", power: true, routes: ["utun0"]).state == .notConnected,
                     "an unrelated tunnel is not reported as Ethernet")
        suite.expect(reading("en0", power: true, routes: ["utun0"], rssi: -52).state == .connected
                     && reading("en0", power: true, routes: [], rssi: -52).state == .connected,
                     "radio association is still visible behind VPN or without a default route")
        suite.expect(reading("en0", power: true, routes: ["utun0", "en0"]).state == .connected,
                     "Wi-Fi can own one IP family's route while a tunnel owns the other")
        suite.expect(reading("en0", power: true, routes: []) == WiFiStatusReading(state: .notConnected, rssi: nil),
                     "a powered radio with neither association nor route is not connected")
        suite.expect(reading("en0", power: false, routes: []) == WiFiStatusReading(state: .poweredOff, rssi: nil),
                     "a powered-off radio is reported as off, not as disconnected")
        suite.expect(reading(nil, power: nil, routes: []) == .unavailable,
                     "a Mac with no Wi-Fi interface reports unavailable")
        suite.expect(reading("en0", power: nil, routes: []) == .unavailable,
                     "a failed power reading reports unavailable instead of guessing")
        suite.expect(reading("en0", power: false, routes: ["en5"]) == WiFiStatusReading(state: .ethernet, rssi: nil),
                     "a cable keeps the Mac online even with the radio switched off")
        suite.expect(reading(nil, power: nil, routes: ["en5"]) == WiFiStatusReading(state: .ethernet, rssi: nil),
                     "a Mac without Wi-Fi hardware still reports its wired route")
    }

    // MARK: - Wi-Fi text

    private static func wifiTextContracts(_ suite: TestSuite) {
        let connected = WiFiStatusReading(state: .connected, rssi: -52)
        suite.expect(WiFiStatusText.value(for: connected, showsSignal: false) == "ON",
                     "a connected Wi-Fi token reads ON without the signal option")
        suite.expect(WiFiStatusText.value(for: connected, showsSignal: true) == "96%",
                     "the signal option shows a 0...100 quality derived from dBm")
        suite.expect(WiFiStatusText.value(for: WiFiStatusReading(state: .connected, rssi: nil), showsSignal: true) == "ON",
                     "a connected reading without RSSI falls back to ON")
        suite.expect(WiFiStatusText.value(for: WiFiStatusReading(state: .notConnected, rssi: nil), showsSignal: true) == "--",
                     "not connected has its own compact value")
        suite.expect(WiFiStatusText.value(for: WiFiStatusReading(state: .ethernet, rssi: nil), showsSignal: true) == "LAN",
                     "Ethernet has its own compact value")
        suite.expect(WiFiStatusText.value(for: WiFiStatusReading(state: .poweredOff, rssi: nil), showsSignal: true) == "OFF",
                     "Wi-Fi off has its own compact value")
        suite.expect(WiFiStatusText.value(for: .unavailable, showsSignal: true) == "N/A",
                     "an unreadable Wi-Fi state says N/A, not not-connected")
        suite.expect(WiFiStatusText.value(for: nil, showsSignal: true) == "N/A",
                     "a missing reading says N/A")
        suite.expect(WiFiStatusText.quality(rssi: -50) == 100
                     && WiFiStatusText.quality(rssi: -70) == 60
                     && WiFiStatusText.quality(rssi: -90) == 20
                     && WiFiStatusText.quality(rssi: -100) == 0
                     && WiFiStatusText.quality(rssi: -20) == 100,
                     "signal quality clamps the dBm mapping to 0...100")
    }

    // MARK: - Volume text

    private static func volumeTextContracts(_ suite: TestSuite) {
        suite.expect(OutputVolumeText.value(for: OutputVolumeReading(level: 0.5, isMuted: false)) == "50%",
                     "an unmuted output shows its rounded percentage")
        suite.expect(OutputVolumeText.value(for: OutputVolumeReading(level: 0, isMuted: false)) == "0%",
                     "a real zero volume is shown as 0%, not as unavailable")
        suite.expect(OutputVolumeText.value(for: OutputVolumeReading(level: 1.2, isMuted: false)) == "100%"
                     && OutputVolumeText.value(for: OutputVolumeReading(level: -1, isMuted: false)) == "0%",
                     "out-of-range levels clamp to 0...100")
        suite.expect(OutputVolumeText.value(for: OutputVolumeReading(level: 0.5, isMuted: true)) == "MUTE",
                     "a muted output says MUTE instead of its hidden level")
        suite.expect(OutputVolumeText.value(for: OutputVolumeReading(level: nil, isMuted: true)) == "MUTE",
                     "MUTE is still readable when the level itself is unavailable")
        suite.expect(OutputVolumeText.value(for: OutputVolumeReading(level: nil, isMuted: false)) == "N/A",
                     "a missing level says N/A, not 0%")
        suite.expect(OutputVolumeText.value(for: OutputVolumeReading(level: nil, isMuted: nil)) == "N/A",
                     "an output with neither reading says N/A")
        suite.expect(OutputVolumeText.value(for: nil) == "N/A",
                     "a missing default-output reading says N/A")
    }
}
