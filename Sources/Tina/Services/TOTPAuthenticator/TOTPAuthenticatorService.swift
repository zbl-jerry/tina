// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Foundation

/// Owns the saved accounts and the Keychain lookups behind them. Account
/// metadata is small and ordered; the secret for each account is fetched from
/// the Keychain on first use and then kept in memory, so showing a countdown
/// does not read the Keychain once per second.
///
/// The metadata string is intentionally absent from the settings backup: a
/// backup cannot carry Keychain items, and restoring labels without their
/// secrets would leave rows that cannot produce a code.
final class TOTPAuthenticatorService: ObservableObject {
    static let shared = TOTPAuthenticatorService()

    /// The shared nspasteboard.org mark for content that must not be recorded.
    /// Clipboard history and other pasteboard readers honor it.
    static let concealedPasteboardType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    @Published private(set) var accounts: [TOTPAccount] = []

    private let defaults: UserDefaults
    private let store: TOTPSecretStore
    private var secrets: [UUID: Data] = [:]
    /// Accounts whose Keychain item was absent once. Remembering the miss
    /// keeps a one-second redraw from asking the Keychain for it again.
    private var missingSecrets = Set<UUID>()
    private var hasLoaded = false

    init(defaults: UserDefaults = .standard,
         store: TOTPSecretStore = TOTPKeychainStore()) {
        self.defaults = defaults
        self.store = store
    }

    // MARK: - Persistence

    func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        accounts = Self.decodeAccounts(defaults.string(forKey: DefaultsKey.totpAccountsData))
    }

    /// Decodes the saved metadata, dropping anything that could not be edited
    /// back into a valid account. The secret is not read here: a locked
    /// keychain must not make a launch look like data loss.
    static func decodeAccounts(_ raw: String?) -> [TOTPAccount] {
        guard let raw, let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([TOTPAccount].self, from: data)
        else { return [] }
        var seen = Set<UUID>()
        return decoded.filter { account in
            account.isWellFormed && seen.insert(account.id).inserted
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(accounts),
              let text = String(data: data, encoding: .utf8)
        else { return }
        defaults.set(text, forKey: DefaultsKey.totpAccountsData)
    }

    // MARK: - Adding

    /// Adds the account described by a parsed setup link.
    @discardableResult
    func add(_ imported: TOTPImportedAccount) -> Result<TOTPAccount, TOTPError> {
        add(name: imported.name, issuer: imported.issuer, secret: imported.secret,
            algorithm: imported.algorithm, digits: imported.digits, period: imported.period)
    }

    /// Adds an account from the manual form. The secret is validated with the
    /// same Base32 rule the link parser uses, so both entry points accept
    /// exactly the same keys.
    @discardableResult
    func add(name: String, issuer: String, secretText: String,
             algorithm: TOTPAlgorithm, digits: Int, period: Int) -> Result<TOTPAccount, TOTPError> {
        let trimmed = secretText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.missingSecret) }
        guard let secret = TOTPSupport.base32Decode(trimmed),
              secret.count >= TOTPSupport.minimumSecretBytes,
              secret.count <= TOTPSupport.maximumSecretBytes
        else { return .failure(.invalidSecret) }
        return add(name: name, issuer: issuer, secret: secret,
                   algorithm: algorithm, digits: digits, period: period)
    }

    private func add(name: String, issuer: String, secret: Data,
                     algorithm: TOTPAlgorithm, digits: Int, period: Int) -> Result<TOTPAccount, TOTPError> {
        guard TOTPSupport.validatedName(name, issuer: issuer) != nil else {
            return .failure(.invalidName)
        }
        guard secret.count >= TOTPSupport.minimumSecretBytes,
              secret.count <= TOTPSupport.maximumSecretBytes
        else { return .failure(.invalidSecret) }
        guard TOTPAccount.allowedDigits.contains(digits) else { return .failure(.invalidDigits) }
        guard TOTPAccount.allowedPeriodRange.contains(period) else {
            return .failure(.invalidPeriod)
        }
        let account = TOTPAccount(name: TOTPSupport.sanitizeLabel(name),
                                  issuer: TOTPSupport.sanitizeLabel(issuer),
                                  algorithm: algorithm,
                                  digits: digits,
                                  period: period)
        guard store.save(secret, for: account.id) else {
            return .failure(.storageFailed)
        }
        secrets[account.id] = secret
        missingSecrets.remove(account.id)
        accounts.append(account)
        persist()
        return .success(account)
    }

    // MARK: - Editing

    @discardableResult
    func rename(_ id: UUID, name: String, issuer: String) -> Bool {
        guard let index = accounts.firstIndex(where: { $0.id == id }),
              TOTPSupport.validatedName(name, issuer: issuer) != nil
        else { return false }
        accounts[index].name = TOTPSupport.sanitizeLabel(name)
        accounts[index].issuer = TOTPSupport.sanitizeLabel(issuer)
        persist()
        return true
    }

    /// Deletes the Keychain item first. If that fails the row stays, so the
    /// list never claims a secret was removed while it is still on the Mac.
    func delete(_ id: UUID) {
        guard store.delete(id) else { return }
        secrets[id] = nil
        missingSecrets.remove(id)
        accounts.removeAll { $0.id == id }
        persist()
    }

    func move(_ id: UUID, by offset: Int) {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard accounts.indices.contains(target) else { return }
        accounts.swapAt(index, target)
        persist()
    }

    // MARK: - Codes

    func code(for account: TOTPAccount, at date: Date = Date()) -> String? {
        guard let secret = secret(for: account.id) else { return nil }
        return TOTPSupport.code(secret: secret,
                                at: date,
                                digits: account.digits,
                                period: account.period,
                                algorithm: account.algorithm)
    }

    func secondsRemaining(for account: TOTPAccount, at date: Date = Date()) -> Int {
        TOTPSupport.secondsRemaining(at: date, period: account.period)
    }

    /// Whether the Keychain answered for this account. A row whose item was
    /// removed outside Tina says so instead of showing a blank code.
    func hasSecret(for id: UUID) -> Bool {
        secret(for: id) != nil
    }

    private func secret(for id: UUID) -> Data? {
        if let cached = secrets[id] { return cached }
        guard !missingSecrets.contains(id) else { return nil }
        guard let stored = store.secret(for: id) else {
            missingSecrets.insert(id)
            return nil
        }
        secrets[id] = stored
        return stored
    }

    /// Puts the current code on the pasteboard as a concealed, Tina-signed
    /// copy. Clipboard history skips concealed items, and the existing
    /// auto-clear rules still see the change and apply to it.
    @discardableResult
    func copy(_ account: TOTPAccount, at date: Date = Date()) -> String? {
        guard let code = code(for: account, at: date) else { return nil }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(code, forType: .string)
        pasteboard.setData(Data(), forType: Self.concealedPasteboardType)
        pasteboard.declareTinaSource()
        return code
    }
}
