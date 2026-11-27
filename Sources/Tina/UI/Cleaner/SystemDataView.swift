// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// A read-only answer to "what is System Data on this Mac". Measuring only;
/// removal stays with the Cleaner's own reviewed categories.
struct SystemDataView: View {
    @ObservedObject var scanner: SystemDataScanner
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 620, minHeight: 460)
        .onAppear {
            if case .idle = scanner.state { scanner.scan() }
        }
    }

    private var scanTitle: String {
        if case .done = scanner.state { return l10n.s.cleanerSystemDataScanAgain }
        return l10n.s.cleanerSystemDataScan
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "internaldrive")
                .foregroundStyle(.secondary)
            Text(l10n.s.cleanerSystemDataTitle)
                .font(.headline)
            Spacer()
            Button(scanTitle) {
                scanner.scan()
            }
            .disabled(scanner.state == .scanning)
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

    @ViewBuilder
    private var content: some View {
        switch scanner.state {
        case .idle, .scanning:
            VStack(spacing: 10) {
                ProgressView()
                Text(l10n.s.cleanerSystemDataCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            Text(l10n.s.cleanerSystemDataUnavailable)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .done(summary):
            VStack(spacing: 0) {
                List {
                    ForEach(summary.groups) { group in
                        DisclosureGroup {
                            if group.top.isEmpty {
                                Text(l10n.s.cleanerSystemDataUnavailable)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(group.top) { entry in
                                HStack {
                                    Text(entry.name)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Text(Self.byteString(entry.bytes))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: symbol(group.category))
                                    .foregroundStyle(.secondary)
                                Text(title(group.category))
                                if !group.complete {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .help(l10n.s.cleanerSystemDataUnavailable)
                                }
                                Spacer()
                                Text(String(format: l10n.s.cleanerSystemDataItemsFormat,
                                            group.itemCount))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(Self.byteString(group.bytes))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.inset)

                if summary.incomplete {
                    Text(l10n.s.cleanerSystemDataUnavailable)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .padding(.bottom, 8)
                }
            }
        }
    }

    private func title(_ category: SystemDataCategory) -> String {
        switch category {
        case .applicationSupport: return l10n.s.cleanerSystemDataApplicationSupport
        case .containers: return l10n.s.cleanerSystemDataContainers
        case .groupContainers: return l10n.s.cleanerSystemDataGroupContainers
        case .caches: return l10n.s.cleanerCatCaches
        case .logs: return l10n.s.cleanerCatLogs
        case .developer: return l10n.s.cleanerCatDeveloper
        case .deviceBackups: return l10n.s.cleanerCatDeviceBackups
        case .trash: return l10n.s.cleanerCatTrash
        }
    }

    private func symbol(_ category: SystemDataCategory) -> String {
        switch category {
        case .applicationSupport: return "shippingbox"
        case .containers, .groupContainers: return "square.stack.3d.up"
        case .caches: return "archivebox"
        case .logs: return "doc.text"
        case .developer: return "hammer"
        case .deviceBackups: return "iphone"
        case .trash: return "trash"
        }
    }

    private static func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
