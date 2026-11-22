// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The window picker shared by the menu panel and Settings. It lists every
/// ordinary window on screen, refreshes while it stays open, and pins one
/// window per row. Pinning never closes the picker, so several windows can be
/// pinned in one visit.
struct WindowPinPickerView: View {
    @ObservedObject var model: WindowPinPickerModel
    let strings: WindowPinningStrings
    let onClose: () -> Void

    @ObservedObject private var permissions = Permissions.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(strings.pickerCaption)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(strings.pickerSearch, text: $model.query)
                    .textFieldStyle(.plain)
                if !model.query.isEmpty {
                    Button {
                        model.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(strings.close)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))

            if !permissions.screenRecording {
                VStack(alignment: .leading, spacing: 8) {
                    Label(strings.permissionNote, systemImage: "hand.raised")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    PermissionRow(kind: .screenRecording)
                }
                .padding(.vertical, 18)
                Spacer(minLength: 0)
            } else if model.filtered.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text(strings.pickerEmpty)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(model.filtered) { candidate in
                            row(candidate)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }

            Divider()

            HStack {
                Text(String(format: strings.pinnedCount, model.pinnedIDs.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Button(strings.refresh) { model.refresh() }
                    .controlSize(.small)
                Button(strings.close, action: onClose)
                    .controlSize(.small)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(minWidth: 380, minHeight: 320)
        .onAppear { model.refresh() }
    }

    private func row(_ candidate: WindowPinCandidate) -> some View {
        HStack(spacing: 10) {
            if let icon = NSRunningApplication(processIdentifier: candidate.pid)?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 26, height: 26)
            } else {
                Image(systemName: "macwindow")
                    .font(.system(size: 18))
                    .frame(width: 26, height: 26)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.displayTitle)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(verbatim: "\(candidate.appName)  \(Int(candidate.frame.width))×\(Int(candidate.frame.height))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if model.pinnedIDs.contains(candidate.id) {
                Text(strings.pinned)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary.opacity(0.6), in: Capsule())
            } else {
                Button(strings.pin) { model.pin(candidate) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }
}
