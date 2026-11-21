// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The menu panel block: what is typing now, whether automatic switching is
/// on, and one tap per enabled source for a manual switch. Rules themselves
/// stay in Settings, where there is room to read them.
struct PanelAutoInputSourceView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = AutoInputSourceService.shared
    @AppStorage(DefaultsKey.autoInputSourceEnabled) private var enabled = false

    var onClose: () -> Void

    private var strings: AutoInputSourceStrings { FeatureStrings.autoInputSource(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            current
            Toggle(strings.enabledLabel, isOn: $enabled)
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .font(.system(size: 11))
                .onChange(of: enabled) { _, _ in
                    AutoInputSourceService.shared.syncWithPreferences()
                }
            sources
        }
        .onAppear { service.reload() }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label(strings.title, systemImage: AppFeature.autoInputSource.symbolName)
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Button {
                SettingsRouter.shared.page = .autoInputSource
                appDelegate()?.openSettingsWindow()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help(l10n.s.menuSettings)
            .accessibilityLabel(l10n.s.menuSettings)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help(l10n.s.uninstallerCancel)
        }
    }

    private var current: some View {
        HStack(spacing: 8) {
            if let reading = service.currentSource {
                Text(reading.code.isEmpty ? "ABC" : reading.code)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 26)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08), in: Capsule())
                VStack(alignment: .leading, spacing: 1) {
                    Text(reading.name.isEmpty ? reading.id : reading.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                    Text(enabled && service.isRunning ? strings.statusRunning : strings.statusStopped)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(strings.noSources)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelCard()
    }

    @ViewBuilder
    private var sources: some View {
        if service.sources.isEmpty {
            Text(strings.noSources)
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .panelCard()
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(strings.manualHint)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                ForEach(service.sources) { source in
                    Button {
                        service.select(sourceID: source.id)
                    } label: {
                        HStack(spacing: 7) {
                            Text(source.code.isEmpty ? "ABC" : source.code)
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 24)
                            Text(source.name)
                                .font(.system(size: 11))
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            if service.currentSource?.id == source.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .panelCard()
        }
    }
}
