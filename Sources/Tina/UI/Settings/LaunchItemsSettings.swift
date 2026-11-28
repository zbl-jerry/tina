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
    @State private var pending: PendingAction?

    private struct PendingAction {
        let action: LaunchItemsSupport.Action
        let item: LaunchItem
    }

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

            if service.hasUnreadableFolders {
                Section {
                    Text(text.unreadable)
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
        .confirmationDialog(pending.map { title(for: $0.action) } ?? "",
                            isPresented: Binding(get: { pending != nil },
                                                 set: { if !$0 { pending = nil } }),
                            titleVisibility: .visible, presenting: pending) { pending in
            Button(title(for: pending.action), role: .destructive) {
                perform(pending.action, on: pending.item)
            }
            Button(l10n.s.uninstallerCancel, role: .cancel) {}
        } message: { pending in
            Text(pending.item.label)
        }
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
                    .foregroundStyle(.secondary)
                if item.canToggle && item.disabledAtLogin == true {
                    Text(text.disabled)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else if item.canToggle && item.state != .unknown && item.disabledAtLogin == nil {
                    Text(text.unreadable)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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
            let actions: [LaunchItemsSupport.Action] =
                [.startForSession, .stopForSession, .enableAtLogin, .disableAtLogin]
            let available = actions.filter { item.allows($0) }
            if !available.isEmpty {
                Menu {
                    ForEach(available) { action in
                        Button(title(for: action)) {
                            if action == .stopForSession || action == .disableAtLogin {
                                pending = PendingAction(action: action, item: item)
                            } else {
                                perform(action, on: item)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(Text(item.label))
                .disabled(service.busyLabels.contains(item.label))
            }
        }
    }

    private func status(_ item: LaunchItem) -> String {
        if !item.canToggle { return text.readOnly }
        switch item.state {
        case .unknown: return text.unreadable
        case .unloaded: return text.unloaded
        case .loaded(_, let running):
            return item.state.matches(item.url) ? (running ? text.loaded : text.loadedIdle) : text.unreadable
        }
    }

    private func title(for action: LaunchItemsSupport.Action) -> String {
        switch action {
        case .startForSession: return text.start
        case .stopForSession: return text.stop
        case .enableAtLogin: return text.enable
        case .disableAtLogin: return text.disable
        }
    }

    private func perform(_ action: LaunchItemsSupport.Action, on item: LaunchItem) {
        errorLabel = nil
        service.perform(action, on: item) { ok in
            if !ok { errorLabel = item.label }
        }
    }
}
