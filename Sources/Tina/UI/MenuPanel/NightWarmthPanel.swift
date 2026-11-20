// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The night warmth block inside the panel's brightness section. It shares
/// the card with the display sliders instead of adding a section of its own,
/// because the two are the same job: what the screens look like right now.
struct NightWarmthPanelBlock: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = NightWarmthService.shared
    @AppStorage(DefaultsKey.nightWarmthEnabled) private var enabled = false

    private var strings: NightWarmthStrings { FeatureStrings.nightWarmth(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(strings.title)
                    .font(.system(size: 11.5, weight: .semibold))
                Spacer(minLength: 6)
                Toggle(strings.title, isOn: $enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            Text(statusText)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            if enabled {
                HStack(spacing: 6) {
                    Button(strings.warmer) { service.adjust(warmer: true) }
                    Button(strings.cooler) { service.adjust(warmer: false) }
                    Spacer(minLength: 4)
                    if service.pausedUntil.map({ $0 > Date() }) == true {
                        Button(strings.resume) { service.resume() }
                    } else {
                        Menu {
                            Button(strings.pauseHour) { service.pause(for: 3600) }
                            Button(service.phase == .bedtime ? strings.pauseUntilWake
                                                             : strings.pauseUntilSunrise) {
                                service.pauseUntilMorning()
                            }
                        } label: {
                            Image(systemName: "pause.circle")
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .accessibilityLabel(strings.pauseHour)
                    }
                }
                .font(.system(size: 10.5, weight: .medium))
                .controlSize(.mini)
                .buttonStyle(.bordered)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 5)], spacing: 5) {
                    ForEach(NightWarmthPreset.kelvins, id: \.self) { kelvin in
                        Button {
                            service.applyPreset(kelvin)
                        } label: {
                            Text("\(Int(kelvin)) K")
                                .font(.system(size: 9.5, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Int(service.targetKelvin) == Int(kelvin)
                                              ? Color.accentColor.opacity(0.22)
                                              : Color.secondary.opacity(0.10))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onChange(of: enabled) { _, _ in service.syncWithPreferences() }
        .onAppear { service.syncWithPreferences() }
    }

    private var statusText: String {
        if let until = service.pausedUntil, until > Date() {
            return String(format: strings.pausedFormat,
                          until.formatted(date: .omitted, time: .shortened))
        }
        return String(format: strings.temperatureFormat,
                      strings.phaseName(service.phase), Int(service.currentKelvin))
    }
}
