// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Quick switching from the menu panel: tick the profiles that should be
/// active, apply once, and see how many lines the system file is using.
struct PanelHostsProfilesView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = HostsProfilesService.shared
    @Environment(\.notchPresentation) private var inNotch
    @State private var pendingRestore: HostsBackup?

    var onClose: () -> Void

    private var strings: HostsProfilesStrings { FeatureStrings.hostsProfiles(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            status
            profiles
            if let failure = service.lastFailure, let text = failureText(failure) {
                Label(text, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .panelCard()
            }
            actions
        }
        .onAppear {
            PanelInteractionState.shared.viewKeepsPopoverOpen = true
            service.load()
            service.refresh()
        }
        .onDisappear { PanelInteractionState.shared.viewKeepsPopoverOpen = false }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var header: some View {
        HStack(spacing: 8) {
            Label(strings.title, systemImage: "network.badge.shield.half.filled")
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Button {
                SettingsRouter.shared.page = .hostsProfiles
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

    private var status: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(statusText)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelCard()
    }

    private var statusColor: Color {
        switch service.state {
        case .applied: return .green
        case .outdated: return .orange
        case .notApplied, .empty, .unknown: return .secondary
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

    @ViewBuilder
    private var profiles: some View {
        if service.profiles.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "network").foregroundStyle(.secondary)
                Text(strings.emptyProfiles)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .panelCard()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(service.profiles) { profile in
                    Toggle(isOn: Binding(
                        get: { profile.isEnabled },
                        set: { service.setEnabled(profile.id, $0) })) {
                        Text(profile.name.isEmpty ? strings.newProfileName : profile.name)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .panelCard()
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Menu {
                if service.backups.isEmpty {
                    Text(strings.noBackups)
                } else {
                    ForEach(service.backups) { backup in
                        Button(backupTitle(backup)) { pendingRestore = backup }
                    }
                }
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .frame(width: 26)
            .disabled(service.backups.isEmpty || service.isWorking)
            .help(strings.restore)

            Spacer()

            Button {
                service.apply()
            } label: {
                Text(service.isWorking ? strings.applying : strings.apply)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(service.isWorking || !HostsProfilesSupport.validate(service.enabledProfiles).isEmpty)
        }
    }

    private func backupTitle(_ backup: HostsBackup) -> String {
        let reason = backup.wasApply ? strings.reasonApply : strings.reasonRestore
        let stamp = backup.modifiedAt.formatted(date: .numeric, time: .shortened)
        return "\(stamp) · \(reason)"
    }

    private func failureText(_ failure: HostsProfilesFailure) -> String? {
        switch failure {
        case .invalid(let issues):
            guard let issue = issues.first else { return nil }
            return message(for: issue)
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
}
