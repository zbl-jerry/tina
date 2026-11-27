// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Diagnoses installed apps that will not open. The only action offered is
/// removing the download quarantine from an app whose signature still
/// verifies; a broken signature is reported, never bypassed.
struct AppRepairSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = AppRepairService.shared
    @State private var pendingRepair: AppRepairCandidate?
    @State private var errorText: String?

    private var text: AppRepairStrings { FeatureStrings.appRepair(l10n.language) }

    var body: some View {
        Form {
            Section {
                Text(text.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorText {
                Section {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            switch service.phase {
            case .idle, .scanning:
                Section {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(text.caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            case .failed:
                Section {
                    Text(text.empty)
                        .foregroundStyle(.secondary)
                }
            case .loaded:
                if service.candidates.isEmpty {
                    Section {
                        Label(text.empty, systemImage: "checkmark.seal")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(service.candidates) { candidate in
                            row(candidate)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if service.phase == .idle { service.scan() }
        }
        .toolbar {
            Button {
                service.scan()
            } label: {
                Label(text.title, systemImage: "arrow.clockwise")
            }
            .disabled(service.phase == .scanning)
        }
        .alert(text.confirmTitle,
               isPresented: Binding(get: { pendingRepair != nil },
                                    set: { if !$0 { pendingRepair = nil } }),
               presenting: pendingRepair) { candidate in
            Button(l10n.s.uninstallerCancel, role: .cancel) { pendingRepair = nil }
            Button(text.removeQuarantine, role: .destructive) {
                if !service.removeQuarantine(candidate) {
                    errorText = text.empty
                }
                pendingRepair = nil
            }
        } message: { candidate in
            Text(String(format: text.confirmMessage, candidate.name))
        }
    }

    private func row(_ candidate: AppRepairCandidate) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: candidate.url.path))
                .resizable()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.name)
                    .font(.system(size: 12, weight: .medium))
                Text(candidate.url.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                ForEach(AppRepairPolicy.sortedIssues(candidate.issues), id: \.self) { issue in
                    Text(label(issue))
                        .font(.caption2)
                        .foregroundStyle(issue == .quarantined ? .orange : .secondary)
                }
            }
            Spacer()
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([candidate.url])
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help(text.caption)
            if candidate.canRemoveQuarantine {
                Button(text.removeQuarantine) {
                    pendingRepair = candidate
                }
            }
        }
    }

    private func label(_ issue: AppRepairIssue) -> String {
        switch issue {
        case .quarantined: return text.quarantined
        case .invalidSignature: return text.invalidSignature
        case .notAccepted: return text.notAccepted
        }
    }
}
