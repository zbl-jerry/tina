// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The full hosts page: profiles on the left, the selected profile's editor on
/// the right, and one apply/restore footer. Validation runs as the text is
/// typed, so an apply is never the first moment a bad line is noticed.
struct HostsProfilesSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = HostsProfilesService.shared
    @State private var selection: UUID?
    @State private var pendingDelete: HostsProfile?
    @State private var pendingRestore: HostsBackup?

    private var strings: HostsProfilesStrings { FeatureStrings.hostsProfiles(l10n.language) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                profileColumn
                    .frame(width: 232)
                Divider()
                editorColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            service.load()
            if selection == nil { selection = service.profiles.first?.id }
        }
        .onChange(of: service.profiles.map(\.id)) { _, ids in
            if let selection, !ids.contains(selection) {
                self.selection = ids.first
            } else if selection == nil {
                selection = ids.first
            }
        }
        .alert(strings.deleteConfirmTitle,
               isPresented: Binding(get: { pendingDelete != nil },
                                    set: { if !$0 { pendingDelete = nil } })) {
            Button(l10n.s.uninstallerCancel, role: .cancel) { pendingDelete = nil }
            Button(strings.delete, role: .destructive) {
                if let pendingDelete { service.delete(pendingDelete.id) }
                pendingDelete = nil
            }
        } message: {
            Text(strings.deleteConfirmMessage)
        }
        .alert(strings.restoreConfirmTitle,
               isPresented: Binding(get: { pendingRestore != nil },
                                    set: { if !$0 { pendingRestore = nil } })) {
            Button(l10n.s.uninstallerCancel, role: .cancel) { pendingRestore = nil }
            Button(strings.restore) {
                if let pendingRestore { service.restore(pendingRestore) }
                pendingRestore = nil
            }
        } message: {
            Text(strings.restoreConfirmMessage)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "network.badge.shield.half.filled")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(strings.title).font(.headline)
                Text(strings.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            statusBadge
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(statusText)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }

    private var statusColor: Color {
        switch service.state {
        case .applied: return .green
        case .outdated: return .orange
        case .notApplied, .empty: return .secondary
        case .unknown: return .secondary
        }
    }

    private var statusText: String {
        switch service.state {
        case .applied(let count): return String(format: strings.statusApplied, count)
        case .outdated(let count): return String(format: strings.statusOutdated, count)
        case .notApplied: return strings.statusNotApplied
        case .empty: return strings.statusEmpty
        case .unknown: return strings.statusUnknown
        }
    }

    // MARK: - Profiles

    private var profileColumn: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(service.profiles) { profile in
                    profileRow(profile)
                        .tag(profile.id)
                        .contextMenu {
                            Button(strings.duplicate) { _ = service.duplicate(profile.id) }
                            Button(strings.delete, role: .destructive) { pendingDelete = profile }
                        }
                }
            }
            .listStyle(.sidebar)
            if service.profiles.isEmpty {
                VStack(spacing: 6) {
                    Text(strings.emptyProfiles).font(.caption).foregroundStyle(.secondary)
                    Text(strings.emptyProfilesHint)
                        .font(.caption2).foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(12)
            }
            Divider()
            HStack(spacing: 2) {
                iconButton("plus", help: strings.addProfile) {
                    let id = service.addProfile()
                    selection = id
                }
                iconButton("doc.on.doc", help: strings.duplicate) {
                    if let selection, let copy = service.duplicate(selection) {
                        self.selection = copy
                    }
                }
                .disabled(selection == nil)
                iconButton("trash", help: strings.delete) {
                    if let profile = selectedProfile { pendingDelete = profile }
                }
                .disabled(selection == nil)
                Spacer()
                iconButton("chevron.up", help: strings.moveUp) {
                    if let selection { service.move(selection, by: -1) }
                }
                .disabled(selection == nil)
                iconButton("chevron.down", help: strings.moveDown) {
                    if let selection { service.move(selection, by: 1) }
                }
                .disabled(selection == nil)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    private func profileRow(_ profile: HostsProfile) -> some View {
        HStack(spacing: 7) {
            Toggle("", isOn: Binding(
                get: { profile.isEnabled },
                set: { service.setEnabled(profile.id, $0) }))
            .labelsHidden()
            .toggleStyle(.checkbox)
            .controlSize(.small)
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name.isEmpty ? strings.newProfileName : profile.name)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                Text(String(format: "%d", entryCount(profile)))
                    .font(.system(size: 9.5, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 1)
    }

    private func entryCount(_ profile: HostsProfile) -> Int {
        HostsProfilesSupport.effectiveLineCount(
            of: HostsProfilesSupport.managedBlock(
                for: [HostsProfile(id: profile.id, name: profile.name,
                                   content: profile.content, isEnabled: true)]))
    }

    private var selectedProfile: HostsProfile? {
        guard let selection else { return nil }
        return service.profiles.first { $0.id == selection }
    }

    // MARK: - Editor

    @ViewBuilder
    private var editorColumn: some View {
        if let profile = selectedProfile {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(strings.nameLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField(strings.namePlaceholder, text: Binding(
                        get: { profile.name },
                        set: { service.updateName(profile.id, to: $0) }))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                }
                Text(strings.contentHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                PlainTextEditor(text: Binding(
                    get: { profile.content },
                    set: { service.updateContent(profile.id, to: $0) }), fontSize: 12)
                .padding(7)
                .background(Color.primary.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08)))
                .frame(minHeight: 180)

                issuesView(for: profile)
                Text(strings.systemNote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "network")
                    .font(.system(size: 24))
                    .foregroundStyle(.tertiary)
                Text(strings.emptyProfiles).font(.callout).foregroundStyle(.secondary)
                Text(strings.emptyProfilesHint)
                    .font(.caption).foregroundStyle(.tertiary)
                Button(strings.addProfile) {
                    selection = service.addProfile()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func issuesView(for profile: HostsProfile) -> some View {
        let issues = service.issues(for: profile.id)
        if !issues.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text(strings.issuesHeader)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.orange)
                ForEach(Array(issues.prefix(6).enumerated()), id: \.offset) { _, issue in
                    Text(message(for: issue))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if issues.count > 6 {
                    Text("+\(issues.count - 6)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if let failure = service.lastFailure, let text = failureText(failure) {
                    Label(text, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                } else {
                    Text(strings.applyHint)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
                Spacer(minLength: 10)
                Menu {
                    if service.backups.isEmpty {
                        Text(strings.noBackups)
                    } else {
                        ForEach(service.backups) { backup in
                            Button(backupTitle(backup)) { pendingRestore = backup }
                        }
                    }
                } label: {
                    Label(strings.restore, systemImage: "clock.arrow.circlepath")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(service.backups.isEmpty || service.isWorking)

                Button {
                    service.apply()
                } label: {
                    if service.isWorking {
                        HStack(spacing: 5) {
                            ProgressView().controlSize(.small)
                            Text(strings.applying)
                        }
                    } else {
                        Text(strings.apply)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(service.isWorking || !enabledIssues.isEmpty)
                .help(enabledIssues.isEmpty ? strings.panelCaption
                      : enabledIssues.first.map(message(for:)) ?? "")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var enabledIssues: [HostsValidationIssue] {
        HostsProfilesSupport.validate(service.enabledProfiles)
    }

    private func backupTitle(_ backup: HostsBackup) -> String {
        let reason = backup.wasApply ? strings.reasonApply : strings.reasonRestore
        let stamp = backup.modifiedAt.formatted(date: .numeric, time: .shortened)
        return "\(stamp) · \(reason)"
    }

    private func failureText(_ failure: HostsProfilesFailure) -> String? {
        switch failure {
        case .invalid(let issues):
            return issues.first.map(message(for:))
        case .readFailed: return strings.failureRead
        case .unbalanced: return strings.failureUnbalanced
        case .backupFailed: return strings.failureBackup
        case .writeFailed: return strings.failureWrite
        case .busy: return strings.failureBusy
        }
    }

    private func message(for issue: HostsValidationIssue) -> String {
        switch issue.reason {
        case .invalidAddress: return String(format: strings.issueInvalidAddress, issue.lineNumber)
        case .missingHostname: return String(format: strings.issueMissingHostname, issue.lineNumber)
        case .invalidHostname: return String(format: strings.issueInvalidHostname, issue.lineNumber)
        case .controlCharacter: return String(format: strings.issueControlCharacter, issue.lineNumber)
        case .lineTooLong: return String(format: strings.issueLineTooLong, issue.lineNumber)
        case .contentTooLarge: return strings.issueContentTooLarge
        case .reservedMarker: return String(format: strings.issueReservedMarker, issue.lineNumber)
        }
    }

    private func iconButton(_ symbol: String, help: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10.5, weight: .semibold))
                .frame(width: 22, height: 20)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}
