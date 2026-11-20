// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The night warmth card on the Energy page: the switch, what the schedule is
/// doing right now, the temperatures each phase uses, the schedule itself and
/// where the sun times come from.
struct NightWarmthSettingsCard: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = NightWarmthService.shared
    @AppStorage(DefaultsKey.nightWarmthEnabled) private var enabled = false
    @AppStorage(DefaultsKey.nightWarmthScheduleMode) private var scheduleMode = NightWarmthScheduleMode.sun.rawValue
    @AppStorage(DefaultsKey.nightWarmthDayKelvin) private var dayKelvin = NightWarmthPreset.neutral
    @AppStorage(DefaultsKey.nightWarmthEveningKelvin) private var eveningKelvin = 3400.0
    @AppStorage(DefaultsKey.nightWarmthBedtimeKelvin) private var bedtimeKelvin = 2700.0
    @AppStorage(DefaultsKey.nightWarmthBedtimeEnabled) private var bedtimeEnabled = false
    @AppStorage(DefaultsKey.nightWarmthTransition) private var transition = NightWarmthTransition.slow.rawValue
    @AppStorage(DefaultsKey.nightWarmthLatitude) private var latitude = 0.0
    @AppStorage(DefaultsKey.nightWarmthLongitude) private var longitude = 0.0
    @AppStorage(DefaultsKey.nightWarmthHasLocation) private var hasLocation = false
    @State private var locationExpanded = false

    private var strings: NightWarmthStrings { FeatureStrings.nightWarmth(l10n.language) }

    var body: some View {
        SettingsCard {
            SettingsRow(symbol: "moon.stars.fill", title: strings.title,
                        caption: strings.caption) {
                Toggle(strings.title, isOn: $enabled)
                    .labelsHidden()
            }
            statusRow
            if enabled {
                Divider()
                presetsRow
                Divider()
                scheduleRows
                bedtimeRows
                Divider()
                transitionRow
                Text(strings.manualCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !service.supported {
                Text(strings.unsupported)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onChange(of: enabled) { _, _ in service.syncWithPreferences() }
        .onChange(of: scheduleMode) { _, _ in service.syncWithPreferences() }
        .onChange(of: bedtimeEnabled) { _, _ in service.syncWithPreferences() }
        .onChange(of: transition) { _, _ in service.syncWithPreferences() }
        .onChange(of: dayKelvin) { _, _ in service.syncWithPreferences() }
        .onChange(of: eveningKelvin) { _, _ in service.syncWithPreferences() }
        .onChange(of: bedtimeKelvin) { _, _ in service.syncWithPreferences() }
        .onAppear { service.syncWithPreferences() }
    }

    // MARK: - Status

    private var statusRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.callout.weight(.medium))
            Spacer()
            if let next = nextChangeText {
                Text(next)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusText: String {
        if let pausedUntil = service.pausedUntil, pausedUntil > Date() {
            return String(format: strings.pausedFormat,
                          pausedUntil.formatted(date: .omitted, time: .shortened))
        }
        return String(format: strings.temperatureFormat,
                      strings.phaseName(service.phase), Int(service.currentKelvin))
    }

    private var nextChangeText: String? {
        guard enabled, service.phase != .paused else { return nil }
        let model = NightWarmthService.model()
        let state = NightWarmthSupport.state(at: Date(), model: model,
                                             timeZone: .current, pausedUntil: service.pausedUntil)
        guard let next = state.nextChange else { return nil }
        return String(format: strings.nextFormat,
                      next.formatted(date: .omitted, time: .shortened))
    }

    private var statusColor: Color {
        switch service.phase {
        case .day: return .secondary
        case .evening: return .orange
        case .bedtime: return .indigo
        case .paused: return .gray
        }
    }

    // MARK: - Presets

    private var presetsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(strings.presets)
                .font(.subheadline.weight(.medium))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 6)], spacing: 6) {
                ForEach(NightWarmthPreset.kelvins, id: \.self) { kelvin in
                    Button {
                        service.applyPreset(kelvin)
                    } label: {
                        Text("\(Int(kelvin)) K")
                            .font(.system(size: 11, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Int(service.targetKelvin) == Int(kelvin)
                                          ? Color.accentColor.opacity(0.22)
                                          : Color.secondary.opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 8) {
                Button(strings.warmer) { service.adjust(warmer: true) }
                Button(strings.cooler) { service.adjust(warmer: false) }
                Spacer()
                Text("\(Int(service.targetKelvin)) K")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .controlSize(.small)
        }
    }

    // MARK: - Schedule

    private var scheduleRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(strings.schedule, selection: $scheduleMode) {
                Text(strings.scheduleSun).tag(NightWarmthScheduleMode.sun.rawValue)
                Text(strings.scheduleCustom).tag(NightWarmthScheduleMode.custom.rawValue)
            }
            .pickerStyle(.segmented)

            if scheduleMode == NightWarmthScheduleMode.custom.rawValue {
                timeRow(title: strings.nightStart, key: DefaultsKey.nightWarmthNightStartMinutes)
                timeRow(title: strings.nightEnd, key: DefaultsKey.nightWarmthNightEndMinutes)
            } else {
                locationRows
            }

            temperatureRow(title: strings.dayPhase, kelvin: $dayKelvin)
            temperatureRow(title: strings.eveningPhase, kelvin: $eveningKelvin)
        }
    }

    private var locationRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                locationExpanded.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "location")
                        .font(.system(size: 10, weight: .semibold))
                    Text(strings.location)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(coordinateText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Image(systemName: locationExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            if locationExpanded {
                HStack(spacing: 10) {
                    coordinateField(title: strings.latitude, value: latitudeBinding)
                    coordinateField(title: strings.longitude, value: longitudeBinding)
                }
                Button(strings.useTimeZone) {
                    hasLocation = false
                    let suggested = NightWarmthSupport.suggestedLocation(for: .current)
                    latitude = suggested.latitude
                    longitude = suggested.longitude
                    service.syncWithPreferences()
                }
                .controlSize(.small)
            }
        }
    }

    private var coordinateText: String {
        let values = effectiveCoordinates
        return values.latitude.formatted(.number.precision(.fractionLength(0...2)))
            + ", " + values.longitude.formatted(.number.precision(.fractionLength(0...2)))
    }

    private var effectiveCoordinates: (latitude: Double, longitude: Double) {
        hasLocation ? (latitude, longitude)
            : NightWarmthSupport.suggestedLocation(for: .current)
    }

    private var latitudeBinding: Binding<Double> {
        Binding(
            get: { effectiveCoordinates.latitude },
            set: { value in
                latitude = value
                hasLocation = true
                service.syncWithPreferences()
            }
        )
    }

    private var longitudeBinding: Binding<Double> {
        Binding(
            get: { effectiveCoordinates.longitude },
            set: { value in
                longitude = value
                hasLocation = true
                service.syncWithPreferences()
            }
        )
    }

    private func coordinateField(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, value: value, format: .number.precision(.fractionLength(0...4)))
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
        }
    }

    private func temperatureRow(title: String, kelvin: Binding<Double>) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Picker(title, selection: kelvin) {
                ForEach(NightWarmthPreset.kelvins, id: \.self) { value in
                    Text("\(Int(value)) K").tag(value)
                }
            }
            .labelsHidden()
            .frame(width: 120)
        }
    }

    // MARK: - Bedtime

    private var bedtimeRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsRow(symbol: "bed.double.fill", title: strings.bedtimeToggle,
                        caption: strings.bedtimeCaption) {
                Toggle(strings.bedtimeToggle, isOn: $bedtimeEnabled)
                    .labelsHidden()
            }
            if bedtimeEnabled {
                timeRow(title: strings.bedtimeTime, key: DefaultsKey.nightWarmthBedtimeMinutes)
                timeRow(title: strings.wakeTime, key: DefaultsKey.nightWarmthWakeMinutes)
                temperatureRow(title: strings.bedtimePhase, kelvin: $bedtimeKelvin)
            }
        }
    }

    private var transitionRow: some View {
        Picker(strings.transition, selection: $transition) {
            Text(strings.transitionSlow).tag(NightWarmthTransition.slow.rawValue)
            Text(strings.transitionFast).tag(NightWarmthTransition.fast.rawValue)
        }
    }

    private func timeRow(title: String, key: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            DatePicker(title, selection: timeBinding(key), displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }

    private func timeBinding(_ key: String) -> Binding<Date> {
        Binding(
            get: {
                let minutes = UserDefaults.standard.integer(forKey: key)
                let start = Calendar.current.startOfDay(for: Date())
                return start.addingTimeInterval(TimeInterval(minutes * 60))
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                UserDefaults.standard.set((parts.hour ?? 0) * 60 + (parts.minute ?? 0), forKey: key)
                service.syncWithPreferences()
            }
        )
    }
}
