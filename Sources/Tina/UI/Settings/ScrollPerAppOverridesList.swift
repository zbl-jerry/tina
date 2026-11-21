// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The per-app half of Smooth scrolling: one row per app with its own
/// smoothing mode, vertical direction and, for Custom, distance per notch and
/// speed. The app picker is the same one the mouse exclusion lists use, so
/// adding an app here feels like adding it anywhere else in Settings.
struct ScrollPerAppOverridesList: View {
    /// The slider above, shown as the value a Custom row inherits until it
    /// sets its own step.
    let globalStep: Int

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var overrides = ScrollPerAppOverrides.shared
    @State private var showingAppPicker = false

    private var text: MouseExceptionStrings { FeatureStrings.mouseExceptions(l10n.language) }

    /// Rows sort by the name the user sees, with the identity breaking ties,
    /// so the same table keeps one order between renders.
    private var sortedItems: [ScrollPerAppOverride] {
        overrides.list().sorted {
            let byName = InstalledApps.name(for: $0.bundleID)
                .localizedCaseInsensitiveCompare(InstalledApps.name(for: $1.bundleID))
            return byName == .orderedSame ? $0.bundleID < $1.bundleID : byName == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(l10n.s.smoothScrollPerAppTitle)
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 8)
                if !sortedItems.isEmpty {
                    Text("\(sortedItems.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(sortedItems, id: \.bundleID) { item in
                row(item)
            }
            Button {
                showingAppPicker = true
            } label: {
                Label(text.addButton, systemImage: "plus")
            }
            .controlSize(.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(l10n.s.smoothScrollPerAppCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .sheet(isPresented: $showingAppPicker) {
            appPicker
        }
    }

    // MARK: - Rows

    private func row(_ item: ScrollPerAppOverride) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 9) {
                Image(nsImage: InstalledApps.icon(for: item.bundleID))
                    .resizable()
                    .frame(width: 18, height: 18)
                Text(InstalledApps.name(for: item.bundleID))
                    .lineLimit(1)
                    .help(item.bundleID)
                Spacer(minLength: 8)
                Picker(l10n.s.smoothScrollPerAppFollow, selection: smoothingBinding(item.bundleID)) {
                    Text(l10n.s.smoothScrollPerAppFollow).tag(ScrollPerAppSmoothing.inherit)
                    Text(l10n.s.smoothScrollPerAppOff).tag(ScrollPerAppSmoothing.off)
                    Text(l10n.s.smoothScrollPerAppCustom).tag(ScrollPerAppSmoothing.custom)
                }
                .labelsHidden()
                .frame(width: 132)
                invertMenu(item)
                Button {
                    overrides.remove(item.bundleID)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(text.removeButton)
            }
            if item.smoothing == .custom {
                VStack(alignment: .leading, spacing: 5) {
                    sliderRow(l10n.s.smoothScrollStepLabel,
                              value: stepBinding(item),
                              range: Double(SmoothScrollSupport.stepRange.lowerBound)
                                  ... Double(SmoothScrollSupport.stepRange.upperBound),
                              step: 10,
                              readout: "\(ScrollPerAppSupport.sanitizedStep(item.step) ?? globalStep)")
                    sliderRow(l10n.s.smoothScrollPerAppSpeedLabel,
                              value: speedBinding(item),
                              range: Double(ScrollPerAppSupport.speedRange.lowerBound)
                                  ... Double(ScrollPerAppSupport.speedRange.upperBound),
                              step: 5,
                              readout: "\(ScrollPerAppSupport.sanitizedSpeedPercent(item.speedPercent))%")
                }
                .padding(.leading, 27)
            }
        }
        .padding(.vertical, 2)
    }

    /// Follow / Inverted / Normal, with the active choice ticked. nil means
    /// the app follows the global vertical inversion.
    private func invertMenu(_ item: ScrollPerAppOverride) -> some View {
        Menu {
            Button {
                overrides.setInvertVertical(nil, for: item.bundleID)
            } label: {
                choice(l10n.s.smoothScrollPerAppFollow, selected: item.invertVertical == nil)
            }
            Button {
                overrides.setInvertVertical(true, for: item.bundleID)
            } label: {
                choice(l10n.s.smoothScrollPerAppInvertInverted, selected: item.invertVertical == true)
            }
            Button {
                overrides.setInvertVertical(false, for: item.bundleID)
            } label: {
                choice(l10n.s.smoothScrollPerAppInvertNormal, selected: item.invertVertical == false)
            }
        } label: {
            Label(l10n.s.smoothScrollPerAppInvertLabel,
                  systemImage: item.invertVertical == nil
                      ? "arrow.up.arrow.down" : "arrow.up.arrow.down.circle.fill")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func choice(_ title: String, selected: Bool) -> some View {
        HStack {
            Text(title)
            if selected { Image(systemName: "checkmark") }
        }
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>,
                           step: Double, readout: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .frame(minWidth: 96, alignment: .leading)
            Slider(value: value, in: range, step: step) {
                Text(title)
            }
            .labelsHidden()
            Text(readout)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .trailing)
        }
    }

    // MARK: - Bindings

    private func smoothingBinding(_ bundleID: String) -> Binding<ScrollPerAppSmoothing> {
        Binding(
            get: {
                overrides.list().first { $0.bundleID == bundleID }?.smoothing ?? .inherit
            },
            set: { overrides.setSmoothing($0, for: bundleID) }
        )
    }

    private func stepBinding(_ item: ScrollPerAppOverride) -> Binding<Double> {
        Binding(
            get: {
                Double(ScrollPerAppSupport.sanitizedStep(
                    overrides.list().first { $0.bundleID == item.bundleID }?.step ?? item.step
                ) ?? globalStep)
            },
            set: { overrides.setStep(Int($0), for: item.bundleID) }
        )
    }

    private func speedBinding(_ item: ScrollPerAppOverride) -> Binding<Double> {
        Binding(
            get: {
                let current = overrides.list().first { $0.bundleID == item.bundleID }?.speedPercent
                    ?? item.speedPercent
                return Double(ScrollPerAppSupport.sanitizedSpeedPercent(current))
            },
            set: { overrides.setSpeedPercent(Int($0), for: item.bundleID) }
        )
    }

    // MARK: - Picker

    private var appPicker: some View {
        let listed = Set(overrides.list().map(\.bundleID))
        return AppPickerView(canBrowseApplications: true,
                             acceptsExecutables: false) {
            showingAppPicker = false
        } onSelect: { url in
            showingAppPicker = false
            guard let identity = MouseAppExceptionSupport.pickedIdentity(for: url),
                  !MouseAppExceptionSupport.isExecutablePathIdentity(identity) else { return }
            overrides.add(identity)
        } onSelectApp: { app in
            showingAppPicker = false
            guard let identity = app.explicitIdentity ?? MouseAppExceptionSupport.pickedIdentity(for: app.url),
                  !MouseAppExceptionSupport.isExecutablePathIdentity(identity) else { return }
            overrides.add(identity)
        } loadApps: {
            InstalledApps.installedBundleApplications(excluding: listed,
                                                      includeRunningApplications: true,
                                                      acceptsExecutables: false)
        }
    }
}
