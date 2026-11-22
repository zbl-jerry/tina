// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The Window pinning page. The list of live mirrors lives here as well as in
/// the panel menu, so a pin can always be found even when its panel is behind
/// another window.
struct WindowPinningSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var service = WindowPinningService.shared
    @AppStorage(DefaultsKey.windowPinningEnabled) private var enabled = false
    @AppStorage(DefaultsKey.windowPinningFrameRate) private var frameRate =
        WindowPinningSupport.defaultFrameRate
    @AppStorage(DefaultsKey.windowPinningHandoff) private var handoff =
        WindowPinHandoff.click.rawValue
    @AppStorage(DefaultsKey.windowPinningKeepFocus) private var keepFocus = true
    @AppStorage(DefaultsKey.windowPinningPauseWhenHidden) private var pauseWhenHidden = true

    private var text: WindowPinningStrings { FeatureStrings.windowPinning(l10n.language) }

    private var frameRateBinding: Binding<Double> {
        Binding {
            Double(WindowPinningSupport.sanitizedFrameRate(frameRate))
        } set: { newValue in
            frameRate = WindowPinningSupport.sanitizedFrameRate(Int(newValue.rounded()))
        }
    }

    private var frameRateBounds: ClosedRange<Double> {
        Double(WindowPinningSupport.frameRateRange.lowerBound)
            ... Double(WindowPinningSupport.frameRateRange.upperBound)
    }

    var body: some View {
        Form {
            Section {
                Toggle(text.enable, isOn: $enabled)
                    .onChange(of: enabled) { _, _ in
                        WindowPinningService.shared.syncWithPreferences()
                    }
                Text(text.enableCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(text.pinWindow) {
                    WindowPinningService.shared.showPicker()
                }
                .disabled(!permissions.screenRecording)
                Label(text.permissionNote, systemImage: "hand.raised")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if enabled {
                Section(text.frameRate) {
                    HStack(spacing: 10) {
                        Slider(value: frameRateBinding, in: frameRateBounds, step: 1)
                        Text(String(format: text.frameRateValue,
                                    WindowPinningSupport.sanitizedFrameRate(frameRate)))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 74, alignment: .trailing)
                    }
                    Text(text.frameRateCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onChange(of: frameRate) { _, _ in
                    WindowPinningService.shared.syncWithPreferences()
                }

                Section(text.handoff) {
                    Picker(text.handoff, selection: $handoff) {
                        Text(text.handoffClick).tag(WindowPinHandoff.click.rawValue)
                        Text(text.handoffHover).tag(WindowPinHandoff.hover.rawValue)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Text(text.handoffCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle(text.keepFocus, isOn: $keepFocus)
                    Text(text.keepFocusCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onChange(of: handoff) { _, _ in
                    WindowPinningService.shared.syncWithPreferences()
                }

                Section {
                    Toggle(text.pauseHidden, isOn: $pauseWhenHidden)
                        .onChange(of: pauseWhenHidden) { _, _ in
                            WindowPinningService.shared.syncWithPreferences()
                        }
                    Text(text.pauseHiddenCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !permissions.screenRecording {
                    Section(l10n.s.permissionRequired) {
                        PermissionRow(kind: .screenRecording)
                    }
                }
                if !permissions.accessibility {
                    Section(l10n.s.permissionRequired) {
                        PermissionRow(kind: .accessibility)
                    }
                }

                if !service.pins.isEmpty {
                    Section(text.title) {
                        ForEach(service.pins) { pin in
                            pinRow(pin)
                        }
                        Button(text.closeAll, role: .destructive) {
                            WindowPinningService.shared.unpinAll()
                        }
                    }
                }
            }
        }
    }

    private func pinRow(_ pin: WindowPinSummary) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pin.title.isEmpty ? pin.appName : pin.title)
                    .lineLimit(1)
                Text(pin.appName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(pin.isPaused ? text.resume : text.pause) {
                WindowPinningService.shared.togglePause(pin.id)
            }
            .controlSize(.small)
            Button(text.unpin) {
                WindowPinningService.shared.unpin(pin.id)
            }
            .controlSize(.small)
        }
    }
}
