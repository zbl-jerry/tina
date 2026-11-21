// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The verification-code page: one row per account, a live code and countdown,
/// and the add, rename and delete flows. The secret is never shown again after
/// it is saved; editing an account changes its label only.
struct TOTPAuthenticatorSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = TOTPAuthenticatorService.shared
    @State private var showsAddSheet = false
    @State private var pendingRename: TOTPAccount?
    @State private var pendingDelete: TOTPAccount?

    private var strings: TOTPAuthenticatorStrings { FeatureStrings.totpAuthenticator(l10n.language) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider()
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(TOTPCaptureShield())
        .onAppear { service.load() }
        .sheet(isPresented: $showsAddSheet) {
            TOTPAddAccountSheet(service: service)
        }
        .sheet(item: $pendingRename) { account in
            TOTPRenameSheet(account: account, service: service)
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
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: AppFeature.totpAuthenticator.symbolName)
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
            Button {
                showsAddSheet = true
            } label: {
                Label(strings.addAccount, systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private var content: some View {
        if service.accounts.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "lock.rotation")
                    .font(.system(size: 26))
                    .foregroundStyle(.secondary)
                Text(strings.emptyTitle)
                    .font(.system(size: 13, weight: .medium))
                Text(strings.emptyHint)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(strings.addAccount) { showsAddSheet = true }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(service.accounts) { account in
                            TOTPAccountRow(account: account,
                                           date: context.date,
                                           strings: strings,
                                           service: service,
                                           rename: { pendingRename = account },
                                           delete: { pendingDelete = account })
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "key.fill")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(strings.localOnlyNote)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }
}

/// One account row. The code stays hidden until the pointer rests on it, so a
/// screenshot of the page does not carry a working code; the panel window also
/// refuses capture while its own list is open.
private struct TOTPAccountRow: View {
    let account: TOTPAccount
    let date: Date
    let strings: TOTPAuthenticatorStrings
    @ObservedObject var service: TOTPAuthenticatorService
    let rename: () -> Void
    let delete: () -> Void

    @State private var revealsCode = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                if !account.issuer.isEmpty, account.issuer != account.displayName {
                    Text(account.issuer)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 180, alignment: .leading)

            Spacer(minLength: 0)

            codeButton

            countdown

            Button {
                copy()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help(strings.copyHint)
            .accessibilityLabel(strings.copy)

            Menu {
                Button(strings.rename, action: rename)
                Button(strings.moveUp) { service.move(account.id, by: -1) }
                    .disabled(!canMove(by: -1))
                Button(strings.moveDown) { service.move(account.id, by: 1) }
                    .disabled(!canMove(by: 1))
                Divider()
                Button(strings.delete, role: .destructive, action: delete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .menuIndicator(.hidden)
            .frame(width: 22)
            .help(strings.rename)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
    }

    private var codeButton: some View {
        Group {
            if let code = service.code(for: account, at: date) {
                Text(revealsCode ? TOTPSupport.grouped(code) : TOTPSupport.maskedCode(digits: account.digits))
                    .font(.system(size: 14.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(revealsCode ? .primary : .secondary)
            } else {
                Text(strings.noSecret)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.orange)
            }
        }
        .frame(width: 128, alignment: .trailing)
        .contentShape(Rectangle())
        .onHover { revealsCode = $0 }
        .onTapGesture { copy() }
        .help(revealsCode ? strings.copyHint : strings.revealHint)
        .accessibilityLabel(account.displayName)
        .accessibilityValue(revealsCode ? strings.copyHint : strings.revealHint)
    }

    private var countdown: some View {
        let remaining = service.secondsRemaining(for: account, at: date)
        let fraction = Double(remaining) / Double(max(1, account.period))
        return HStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(Color.accentColor,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 16, height: 16)
            Text(String(format: strings.secondsFormat, remaining))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
        }
    }

    private func canMove(by offset: Int) -> Bool {
        guard let index = service.accounts.firstIndex(where: { $0.id == account.id }) else {
            return false
        }
        return service.accounts.indices.contains(index + offset)
    }

    private func copy() {
        guard service.copy(account, at: date) != nil else { return }
        QuickToolHUD.show(icon: AppFeature.totpAuthenticator.symbolName,
                          message: strings.copied)
    }
}

/// The add flow. A setup link fills the same fields the manual form uses, so
/// there is exactly one validation path and one place where the secret is
/// written to the Keychain.
struct TOTPAddAccountSheet: View {
    @ObservedObject var service: TOTPAuthenticatorService
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss

    @State private var linkText = ""
    @State private var name = ""
    @State private var issuer = ""
    @State private var secretText = ""
    @State private var algorithm: TOTPAlgorithm = .sha1
    @State private var digits = TOTPSupport.defaultDigits
    @State private var period = TOTPSupport.defaultPeriod
    @State private var showsAdvanced = false
    @State private var error: TOTPError?
    @State private var notice: String?

    private var strings: TOTPAuthenticatorStrings { FeatureStrings.totpAuthenticator(l10n.language) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: AppFeature.totpAuthenticator.symbolName)
                    .foregroundStyle(Color.accentColor)
                Text(strings.addTitle).font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    linkSection
                    Divider()
                    manualSection
                    advancedSection
                    if let error {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(strings.errorTitle)
                                .font(.system(size: 11, weight: .medium))
                            Text(error.message(strings))
                                .font(.system(size: 11))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(.orange)
                    }
                    if let notice {
                        Label(notice, systemImage: "info.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(strings.localOnlyNote)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }

            Divider()
            HStack {
                Spacer()
                Button(strings.cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(strings.save) { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 480)
        .frame(minHeight: 460)
        .background(TOTPCaptureShield())
        .onDisappear { ScreenTextService.shared.cancelQRPayload() }
    }

    private var linkSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(strings.pasteLabel)
                .font(.system(size: 11.5, weight: .medium))
            HStack(spacing: 8) {
                TextField(strings.pastePlaceholder, text: $linkText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11.5, design: .monospaced))
                Button(strings.useLink) { useLink() }
                    .disabled(linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text(strings.pasteHelp)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button {
                    scanQRCode()
                } label: {
                    Label(strings.scanQR, systemImage: "qrcode.viewfinder")
                }
                .disabled(!AppFeature.screenOCR.isAvailable)
                if !AppFeature.screenOCR.isAvailable {
                    Text(strings.scanUnavailable)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(strings.scanHint)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
    }

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(strings.manualHeader)
                .font(.system(size: 11.5, weight: .medium))
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    label(strings.nameLabel)
                    TextField(strings.namePlaceholder, text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    label(strings.issuerLabel)
                    TextField(strings.issuerPlaceholder, text: $issuer)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    label(strings.secretLabel)
                    TextField(strings.secretPlaceholder, text: $secretText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11.5, design: .monospaced))
                }
            }
            Text(strings.secretHelp)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var advancedSection: some View {
        DisclosureGroup(isExpanded: $showsAdvanced) {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    label(strings.algorithmLabel)
                    Picker("", selection: $algorithm) {
                        ForEach(TOTPAlgorithm.allCases) { algorithm in
                            Text(algorithm.rawValue).tag(algorithm)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 120, alignment: .leading)
                }
                GridRow {
                    label(strings.digitsLabel)
                    Picker("", selection: $digits) {
                        Text("6").tag(6)
                        Text("8").tag(8)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                }
                GridRow {
                    label(strings.periodLabel)
                    HStack(spacing: 6) {
                        TextField("", value: $period, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                        Text(String(format: strings.secondsFormat, period))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Text(strings.advancedLabel)
                .font(.system(size: 11.5, weight: .medium))
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
            .gridColumnAlignment(.trailing)
            .frame(width: 110, alignment: .trailing)
    }

    private var canSave: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !issuer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasName && !secretText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func useLink() {
        switch TOTPSupport.parse(linkText) {
        case .success(let imported):
            fill(from: imported)
        case .failure(let failure):
            error = failure
            notice = nil
        }
    }

    private func fill(from imported: TOTPImportedAccount) {
        name = imported.name
        issuer = imported.issuer
        secretText = TOTPSupport.base32Encode(imported.secret)
        algorithm = imported.algorithm
        digits = imported.digits
        period = imported.period
        error = nil
        notice = nil
    }

    private func scanQRCode() {
        guard AppFeature.screenOCR.isAvailable else {
            notice = strings.scanUnavailable
            return
        }
        guard Permissions.shared.screenRecording else {
            notice = "\(l10n.s.permissionRequired): \(l10n.s.permissionScreenRecording)"
            Permissions.shared.requestScreenRecording()
            return
        }
        notice = strings.scanHint
        ScreenTextService.shared.captureQRPayload { payload in
            // A selection can contain more than one code; take the first
            // setup link that parses, and say so when none does.
            for candidate in payload.split(separator: "\n") {
                if case .success(let imported) = TOTPSupport.parse(String(candidate)) {
                    fill(from: imported)
                    return
                }
            }
            notice = strings.scanNoCode
        }
    }

    private func save() {
        switch service.add(name: name, issuer: issuer, secretText: secretText,
                           algorithm: algorithm, digits: digits, period: period) {
        case .success:
            dismiss()
        case .failure(let failure):
            error = failure
            notice = nil
        }
    }
}

/// Renaming changes the row's label only. The secret, algorithm and period
/// stay as saved, so a typo cannot silently invalidate working codes.
struct TOTPRenameSheet: View {
    let account: TOTPAccount
    @ObservedObject var service: TOTPAuthenticatorService
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var issuer: String

    private var strings: TOTPAuthenticatorStrings { FeatureStrings.totpAuthenticator(l10n.language) }

    init(account: TOTPAccount, service: TOTPAuthenticatorService) {
        self.account = account
        self.service = service
        _name = State(initialValue: account.name)
        _issuer = State(initialValue: account.issuer)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(strings.rename).font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text(strings.nameLabel)
                        .foregroundStyle(.secondary)
                    TextField(strings.namePlaceholder, text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text(strings.issuerLabel)
                        .foregroundStyle(.secondary)
                    TextField(strings.issuerPlaceholder, text: $issuer)
                        .textFieldStyle(.roundedBorder)
                }
            }
            HStack {
                Spacer()
                Button(strings.cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(strings.save) {
                    if service.rename(account.id, name: name, issuer: issuer) {
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          && issuer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

extension TOTPError {
    func message(_ strings: TOTPAuthenticatorStrings) -> String {
        switch self {
        case .notOTPAuth: return strings.errorNotOTPAuth
        case .unsupportedType: return strings.errorUnsupportedType
        case .missingSecret: return strings.errorMissingSecret
        case .invalidSecret: return strings.errorInvalidSecret
        case .invalidDigits: return strings.errorInvalidDigits
        case .invalidPeriod: return strings.errorInvalidPeriod
        case .invalidAlgorithm: return strings.errorInvalidAlgorithm
        case .invalidLabel: return strings.errorInvalidLabel
        case .malformed: return strings.errorMalformed
        case .storageFailed: return strings.errorStorage
        case .invalidName: return strings.errorInvalidName
        }
    }
}
