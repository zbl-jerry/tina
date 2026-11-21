// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The menu panel's code list. A code is masked until the pointer rests on its
/// row, clicking copies it, and the whole panel window refuses screen capture
/// while this list is on screen. Adding and editing stay on the Settings page,
/// where the setup flow has room.
struct PanelTOTPAuthenticatorView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = TOTPAuthenticatorService.shared
    /// The quick launcher draws its own header and back button, so the hosted
    /// form omits this one and leaves the launcher's chrome in charge.
    var showsHeader = true
    var onClose: () -> Void

    private var strings: TOTPAuthenticatorStrings { FeatureStrings.totpAuthenticator(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsHeader {
                header
            }
            if service.accounts.isEmpty {
                emptyState
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 6) {
                        ForEach(service.accounts) { account in
                            TOTPPanelRow(account: account,
                                         date: context.date,
                                         strings: strings,
                                         service: service)
                        }
                    }
                }
            }
        }
        .onAppear {
            if showsHeader {
                PanelInteractionState.shared.viewKeepsPopoverOpen = true
            }
            service.load()
        }
        .onDisappear {
            if showsHeader {
                PanelInteractionState.shared.viewKeepsPopoverOpen = false
            }
        }
        .background(TOTPCaptureShield())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label(strings.title, systemImage: AppFeature.totpAuthenticator.symbolName)
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Button(action: openSettings) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help(strings.addAccount)
            .accessibilityLabel(strings.addAccount)
            Button(action: openSettings) {
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

    private var emptyState: some View {
        VStack(spacing: 7) {
            Image(systemName: "lock.rotation")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
            Text(strings.emptyTitle)
                .font(.system(size: 11.5, weight: .medium))
            Text(strings.emptyHint)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(strings.addAccount, action: openSettings)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .panelCard()
    }

    private func openSettings() {
        SettingsRouter.shared.page = .totpAuthenticator
        appDelegate()?.openSettingsWindow()
    }
}

private struct TOTPPanelRow: View {
    let account: TOTPAccount
    let date: Date
    let strings: TOTPAuthenticatorStrings
    @ObservedObject var service: TOTPAuthenticatorService

    @State private var revealsCode = false

    var body: some View {
        Button(action: copy) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(account.displayName)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                    if !account.issuer.isEmpty, account.issuer != account.displayName {
                        Text(account.issuer)
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                codeText
                countdown
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { revealsCode = $0 }
        .help(revealsCode ? strings.copyHint : strings.revealHint)
        .accessibilityLabel(account.displayName)
        .accessibilityValue(revealsCode ? strings.copyHint : strings.revealHint)
        .panelCard()
    }

    @ViewBuilder
    private var codeText: some View {
        if let code = service.code(for: account, at: date) {
            Text(revealsCode ? TOTPSupport.grouped(code) : TOTPSupport.maskedCode(digits: account.digits))
                .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                .foregroundStyle(revealsCode ? .primary : .secondary)
        } else {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
                .help(strings.noSecret)
        }
    }

    private var countdown: some View {
        let remaining = service.secondsRemaining(for: account, at: date)
        let fraction = Double(remaining) / Double(max(1, account.period))
        return ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 2)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 14, height: 14)
    }

    private func copy() {
        guard service.copy(account, at: date) != nil else { return }
        QuickToolHUD.show(icon: AppFeature.totpAuthenticator.symbolName, message: strings.copied)
    }
}

/// Excludes the panel window from screen captures while the code list is
/// visible, and puts the previous sharing setting back when it leaves. This is
/// the same public `NSWindow.sharingType` switch the brightness overlay uses.
struct TOTPCaptureShield: NSViewRepresentable {
    final class Coordinator {
        var previous: NSWindow.SharingType?
        var cancelled = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        let coordinator = context.coordinator
        DispatchQueue.main.async {
            // A view that left the hierarchy before this ran must not exclude
            // a window that no longer hosts a code list.
            guard !coordinator.cancelled, let window = view.window else { return }
            coordinator.previous = window.sharingType
            window.sharingType = .none
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.cancelled = true
        guard let window = nsView.window else { return }
        window.sharingType = coordinator.previous ?? .readOnly
    }
}
