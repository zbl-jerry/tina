// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Lists launchd's login agents and daemons. Only the user's own agents can
/// be stopped or started; the system folders are shown read-only and nothing
/// is ever deleted here.
struct LaunchItemsSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = LaunchItemsService.shared
    @State private var errorLabel: String?

    private var text: LaunchItemsStrings { FeatureStrings.launchItems(l10n.language) }

    var body: some View {
        Form {
            Section {
                Text(text.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorLabel {
                Section {
                    Text("\(text.failed) \(errorLabel)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if service.phase == .loading && service.items.isEmpty {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            } else {
                section(title: text.sectionUser,
                        items: service.items.filter { $0.scope == .userAgent })
                section(title: text.sectionSystem,
                        items: service.items.filter { $0.scope != .userAgent })
            }
        }
        .formStyle(.grouped)
        .onAppear { service.refresh() }
        .toolbar {
            Button {
                service.refresh()
            } label: {
                Label(text.reload, systemImage: "arrow.clockwise")
            }
        }
    }

    @ViewBuilder
    private func section(title: String, items: [LaunchItem]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { item in
                    row(item)
                }
            }
        }
    }

    private func row(_ item: LaunchItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.canToggle ? "gearshape.2" : "lock")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let program = item.program {
                    Text(program)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Text(status(item))
                    .font(.caption2)
                    .foregroundStyle(item.canToggle && !item.loaded && item.disabledByTina
                                     ? .orange : .secondary)
            }
            Spacer()
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help(text.reveal)
            .accessibilityLabel(text.reveal)
            if item.canToggle {
                Button(item.loaded ? text.stop : text.start) {
                    errorLabel = nil
                    service.setEnabled(item, !item.loaded) { ok in
                        if !ok { errorLabel = item.label }
                    }
                }
                .disabled(service.busyLabels.contains(item.label))
            }
        }
    }

    private func status(_ item: LaunchItem) -> String {
        if !item.canToggle { return text.readOnly }
        if item.loaded { return text.loaded }
        return item.disabledByTina ? text.stopped : text.notRunning
    }
}
