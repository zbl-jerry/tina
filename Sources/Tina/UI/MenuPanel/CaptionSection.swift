// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Live captions in the menu panel: one start/stop control, the line being
/// spoken, and the sessions that can be exported or copied.
struct CaptionSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = CaptionService.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.captionsEnabled) private var enabled = false
    var collapsible = true

    private var strings: CaptionFeatureStrings {
        FeatureStrings.captions(l10n.language)
    }

    var body: some View {
        PanelSection(.captions, title: strings.title, collapsible: collapsible) {
            VStack(alignment: .leading, spacing: 10) {
                statusRow
                if let notice = service.notice {
                    Text(notice)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !service.liveText.isEmpty {
                    Text(service.liveText)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                }
                sessions
                HStack(spacing: 8) {
                    Button(strings.resetPosition) {
                        service.resetOverlayPosition()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Spacer()
                    Button(l10n.s.menuSettings) { openSettings() }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear { service.refreshRecent() }
        }
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.system(size: 13, weight: .medium))
                if service.isListening {
                    Text(strings.privacyNote)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if !permissions.speechRecognition.isGranted {
                Button(l10n.s.permissionRequired) { requestSpeech() }
                    .controlSize(.small)
            } else {
                Button(service.isListening ? strings.stop : strings.start) {
                    service.toggle()
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .tint(service.isListening ? .red : .accentColor)
                .disabled(service.isBusy)
            }
        }
    }

    private var sessions: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                sectionTitle(strings.recentSessions)
                Spacer()
            }
            if service.recentSessions.isEmpty {
                Text(strings.noSessions)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(service.recentSessions.prefix(4))) { session in
                    sessionRow(session)
                }
            }
        }
    }

    private func sessionRow(_ session: CaptionSession) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "captions.bubble")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(CaptionSupport.sessionTitle(session))
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(CaptionSupport.clock(session.duration))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 6)
            Menu {
                Button(strings.exportSRT) { export(session, .srt) }
                Button(strings.exportMarkdown) { export(session, .markdown) }
                Button(strings.exportPlainText) { export(session, .plainText) }
                Divider()
                Button(strings.copyAll) { service.copyAllText(session) }
                Divider()
                Button(strings.deleteSession, role: .destructive) { delete(session) }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        switch service.phase {
        case .listening: return .red
        case .starting, .stopping: return .orange
        case .failed: return .orange
        case .idle: return .secondary
        }
    }

    private var statusText: String {
        switch service.phase {
        case .listening: return strings.listening
        case .starting, .stopping: return strings.starting
        case .failed: return strings.idle
        case .idle: return strings.idle
        }
    }

    private func export(_ session: CaptionSession, _ format: CaptionExportFormat) {
        guard let url = service.export(session, as: format) else { return }
        service.reveal(url)
    }

    private func delete(_ session: CaptionSession) {
        let alert = NSAlert()
        alert.messageText = strings.deleteSession
        alert.informativeText = strings.deleteConfirm
        alert.addButton(withTitle: l10n.s.uninstallerRemove)
        alert.addButton(withTitle: l10n.s.uninstallerCancel)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        service.delete(session)
    }

    private func requestSpeech() {
        switch permissions.speechRecognition {
        case .undetermined:
            permissions.requestSpeechRecognition()
        default:
            permissions.openSpeechRecognitionSettings()
        }
    }

    private func openSettings() {
        SettingsRouter.shared.request(AppFeature.captions.settingsDestination)
        appDelegate()?.openSettingsWindow()
    }
}

extension Permissions.SpeechPermissionState {
    var isGranted: Bool { self == .granted }
}
