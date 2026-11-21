// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The charge limit card on the Energy page. The Mac's capability and the
/// helper's approval state both decide what can be shown: an unsupported Mac
/// gets one explanatory row, an unapproved one gets the approval row, and a
/// working one gets the limit itself.
struct ChargeLimitSettingsCard: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = ChargeLimitService.shared
    @AppStorage(DefaultsKey.chargeLimitEnabled) private var enabled = false
    @AppStorage(DefaultsKey.chargeLimitPercent) private var percent = ChargeLimitPolicy.defaultPercent

    private var strings: ChargeLimitStrings { FeatureStrings.chargeLimit(l10n.language) }

    var body: some View {
        SettingsCard(title: strings.title) {
            if ChargeLimitHardware.hasChargeControl {
                SettingsRow(symbol: "battery.75percent", title: strings.toggle,
                            caption: strings.caption) {
                    Toggle(strings.toggle, isOn: $enabled)
                        .labelsHidden()
                }
                if enabled {
                    limitRow
                    statusRow
                    chargeToFullRow
                }
                Text(strings.restoreCaption)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                SettingsRow(symbol: "battery.75percent", title: strings.title,
                            caption: strings.unsupported) {
                    EmptyView()
                }
            }
        }
        .onAppear {
            percent = Defaults.sanitizedChargeLimitPercent(percent)
            service.syncWithPreferences()
        }
        .onChange(of: enabled) { _, _ in
            service.syncWithPreferences()
        }
        .onChange(of: percent) { _, newValue in
            let sanitized = Defaults.sanitizedChargeLimitPercent(newValue)
            if sanitized != newValue { percent = sanitized; return }
            if enabled { service.applyLimit() }
        }
    }

    private var upperPercent: Int { Defaults.sanitizedChargeLimitPercent(percent) }

    private var limitRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsRow(symbol: "slider.horizontal.3", title: strings.upperLimit,
                        caption: String(format: strings.lowerBoundFormat,
                                        ChargeLimitPolicy.lowerBound(forUpper: upperPercent))) {
                Text("\(upperPercent)%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(get: { Double(upperPercent) },
                                  set: { percent = Int($0.rounded()) }),
                   in: Double(ChargeLimitPolicy.minimumPercent)...Double(ChargeLimitPolicy.maximumPercent),
                   step: 1)
                .padding(.leading, settingsRowTextInset)
        }
    }

    private var statusRow: some View {
        SettingsRow(symbol: statusSymbol, title: strings.title,
                    caption: statusCaption) {
            if service.accessState == .requiresApproval || service.accessState == .notRegistered {
                Button(strings.openLoginItems) { service.authorize() }
            } else if let percent = service.status.percent {
                Text("\(percent)%")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else {
                EmptyView()
            }
        }
    }

    private var chargeToFullRow: some View {
        SettingsRow(symbol: "bolt.batteryblock", title: strings.chargeToFull,
                    caption: service.status.chargeToFull ? strings.chargeToFullActive
                                                         : strings.runningWhileTina) {
            Button(strings.chargeToFull) { service.chargeToFull() }
                .disabled(service.accessState != .enabled || service.status.chargeToFull)
        }
    }

    private var statusSymbol: String {
        if service.status.isInhibited { return "pause.circle" }
        if service.status.isCharging { return "bolt.fill" }
        return "powerplug"
    }

    /// The status line lives in the caption, not the title: the title must be a
    /// fixed label so Settings search can follow it.
    private var statusCaption: String? {
        if service.accessState == .requiresApproval { return strings.approvalRequired }
        switch service.error {
        case .some(.verificationFailed): return strings.errorVerificationFailed
        case .some: return strings.errorControlFailed
        case .none: break
        }
        if let percent = service.status.percent {
            if service.status.chargeToFull { return strings.chargeToFullActive }
            if service.status.isInhibited { return String(format: strings.holdingFormat, percent) }
            if service.status.isCharging {
                return String(format: strings.chargingFormat, upperPercent)
            }
        }
        if !service.status.isPluggedIn, service.status.percent != nil {
            return strings.onBattery
        }
        return nil
    }
}
