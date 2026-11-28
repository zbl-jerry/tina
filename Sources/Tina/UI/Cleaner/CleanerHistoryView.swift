// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// What the last cleans did: each item, where it went in the Trash and what
/// stayed behind. Read-only on purpose; the Trash is the restore path.
struct CleanerHistoryView: View {
    @ObservedObject var history: CleanerRunHistory
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if history.runs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(.secondary)
                    Text(l10n.s.cleanerHistoryEmpty)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(history.runs) { run in
                        Section {
                            ForEach(Array(run.entries.enumerated()), id: \.offset) { _, entry in
                                row(entry)
                            }
                        } header: {
                            sectionHeader(run)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 620, minHeight: 460)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.secondary)
            Text(l10n.s.cleanerHistoryTitle)
                .font(.headline)
            Spacer()
            Button(l10n.s.cleanerHistoryClear) {
                history.clear()
            }
            .disabled(history.runs.isEmpty)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(l10n.s.uninstallerCancel)
        }
        .padding(12)
    }

    private func sectionHeader(_ run: CleanerRun) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(run.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .fontWeight(.medium)
                Text(run.origin == .automatic
                     ? l10n.s.cleanerHistoryAutomatic
                     : l10n.s.cleanerHistoryManual)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(String(format: l10n.s.cleanerHistorySummaryFormat,
                        Self.byteString(run.moved), Self.byteString(run.freed), run.leftBehindCount))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func row(_ entry: CleanerRunEntry) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol(entry.outcome))
                .foregroundStyle(color(entry.outcome))
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name)
                    .lineLimit(1)
                Text(entry.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(Self.byteString(entry.size))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            if entry.revealableTrashURL != nil {
                Button(l10n.s.cleanerHistoryShowInFinder) {
                    guard let url = entry.revealableTrashURL else { return }
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
    }

    private func symbol(_ outcome: CleanerRunOutcome) -> String {
        switch outcome {
        case .trashed, .emptied: return "checkmark.circle.fill"
        case .skipped: return "minus.circle"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private func color(_ outcome: CleanerRunOutcome) -> Color {
        switch outcome {
        case .trashed, .emptied: return .green
        case .skipped: return .secondary
        case .failed: return .orange
        }
    }

    private static func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
