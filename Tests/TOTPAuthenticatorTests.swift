// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// The verification-code feature holds two credentials-adjacent contracts:
/// the RFC 6238 calculation and the Keychain boundary. Both are exercised
/// here without a window; the service runs against an in-memory secret store
/// and an isolated preferences domain.
enum TOTPAuthenticatorTests {
    private final class MemoryStore: TOTPSecretStore {
        var values: [UUID: Data] = [:]
        var failSaves = false
        var failDeletes = false

        func secret(for id: UUID) -> Data? { values[id] }

        func save(_ secret: Data, for id: UUID) -> Bool {
            guard !failSaves else { return false }
            values[id] = secret
            return true
        }

        func delete(_ id: UUID) -> Bool {
            guard !failDeletes else { return false }
            values[id] = nil
            return true
        }
    }

    private static func bytes(_ text: String) -> Data { Data(text.utf8) }

    private static func date(_ seconds: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(seconds))
    }

    static func run(_ suite: TestSuite) {
        base32(suite)
        rfc6238(suite)
        timing(suite)
        parsing(suite)
        service(suite)
        display(suite)
    }

    // MARK: - Base32

    private static func base32(_ suite: TestSuite) {
        suite.expect(TOTPSupport.base32Decode("JBSWY3DP") == bytes("Hello"),
                     "Base32 decodes a whole-byte phrase")
        suite.expect(TOTPSupport.base32Decode("jbswy3dp") == bytes("Hello"),
                     "Base32 decoding ignores case")
        suite.expect(TOTPSupport.base32Decode("JBSW Y3DP") == bytes("Hello"),
                     "spaces in a pasted key are ignored")
        suite.expect(TOTPSupport.base32Decode("JBSW-Y3DP") == bytes("Hello"),
                     "hyphens in a pasted key are ignored")
        suite.expect(TOTPSupport.base32Decode("JBSWY3DP====") == bytes("Hello"),
                     "trailing Base32 padding is accepted")
        suite.expect(TOTPSupport.base32Decode("JBSWY3DPEHPK3PXP")?.count == 10,
                     "the common authenticator key length decodes to ten bytes")
        for invalid in ["", "JBSWY3D0", "JBSWY3D1", "JBSWY3D8", "JBSW=Y3DP",
                        "=JBSWY3DP", "££££", "A"] {
            suite.expect(TOTPSupport.base32Decode(invalid) == nil,
                         "\(invalid.debugDescription) is not a Base32 key")
        }

        suite.expect(TOTPSupport.base32Encode(bytes("Hello")) == "JBSWY3DP",
                     "Base32 encoding matches the RFC 4648 example")
        suite.expect(TOTPSupport.base32Encode(Data()) == "",
                     "an empty secret encodes to empty text")
        var allBytes = Data()
        for value in 0...255 { allBytes.append(UInt8(value)) }
        suite.expect(TOTPSupport.base32Decode(TOTPSupport.base32Encode(allBytes)) == allBytes,
                     "every byte value survives an encode and decode round trip")
        suite.expect(TOTPSupport.base32Decode(TOTPSupport.base32Encode(bytes("12345678901234567890")))
                        == bytes("12345678901234567890"),
                     "an ASCII secret survives a round trip")
    }

    // MARK: - RFC 6238 Appendix B

    private static func rfc6238(_ suite: TestSuite) {
        let sha1Secret = bytes("12345678901234567890")
        let sha256Secret = bytes("12345678901234567890123456789012")
        let sha512Secret = bytes(
            "1234567890123456789012345678901234567890123456789012345678901234")

        let vectors: [(time: Int, sha1: String, sha256: String, sha512: String)] = [
            (59, "94287082", "46119246", "90693936"),
            (1111111109, "07081804", "68084774", "25091201"),
            (1111111111, "14050471", "67062674", "99943326"),
            (1234567890, "89005924", "91819424", "93441116"),
            (2000000000, "69279037", "90698825", "38618901"),
            (20000000000, "65353130", "77737706", "47863826"),
        ]
        for vector in vectors {
            let moment = date(vector.time)
            suite.expect(TOTPSupport.code(secret: sha1Secret, at: moment, digits: 8,
                                          period: 30, algorithm: .sha1) == vector.sha1,
                         "SHA1 TOTP matches RFC 6238 at \(vector.time)")
            suite.expect(TOTPSupport.code(secret: sha256Secret, at: moment, digits: 8,
                                          period: 30, algorithm: .sha256) == vector.sha256,
                         "SHA256 TOTP matches RFC 6238 at \(vector.time)")
            suite.expect(TOTPSupport.code(secret: sha512Secret, at: moment, digits: 8,
                                          period: 30, algorithm: .sha512) == vector.sha512,
                         "SHA512 TOTP matches RFC 6238 at \(vector.time)")
        }

        suite.expect(TOTPSupport.code(secret: sha1Secret, at: date(59), digits: 6,
                                      period: 30, algorithm: .sha1) == "287082",
                     "six digits keep the low digits of the same calculation")
        suite.expect(TOTPSupport.code(secret: sha256Secret, at: date(59), digits: 6,
                                      period: 30, algorithm: .sha256) == "119246",
                     "six-digit SHA256 keeps the low digits")
        suite.expect(TOTPSupport.code(secret: sha1Secret, at: date(59), digits: 7,
                                      period: 30, algorithm: .sha1) == "",
                     "an unsupported digit count produces no code")
        suite.expect(TOTPSupport.code(secret: Data(), at: date(59), digits: 6,
                                      period: 30, algorithm: .sha1) == "",
                     "an empty secret produces no code")
    }

    // MARK: - Time steps

    private static func timing(_ suite: TestSuite) {
        suite.expect(TOTPSupport.counter(at: date(0), period: 30) == 0,
                     "the epoch is step zero")
        suite.expect(TOTPSupport.counter(at: date(59), period: 30) == 1,
                     "the last second of a step belongs to that step")
        suite.expect(TOTPSupport.counter(at: date(60), period: 30) == 2,
                     "a new step begins on the boundary")
        suite.expect(TOTPSupport.counter(at: date(-5), period: 30) == 0,
                     "times before the epoch do not wrap the counter")

        suite.expect(TOTPSupport.secondsRemaining(at: date(59), period: 30) == 1,
                     "one second is left at the end of a step")
        suite.expect(TOTPSupport.secondsRemaining(at: date(60), period: 30) == 30,
                     "a fresh step reports the full period")
        suite.expect(TOTPSupport.secondsRemaining(at: date(60), period: 60) == 60,
                     "a custom period reports its own length")
        suite.expect(TOTPSupport.secondsRemaining(at: date(91), period: 60) == 29,
                     "a custom period counts down inside the step")
        suite.expect(TOTPSupport.secondsRemaining(at: date(5), period: 0) == 1,
                     "a zero period is clamped instead of dividing by zero")
    }

    // MARK: - otpauth links

    private static func parsing(_ suite: TestSuite) {
        let link = "otpauth://totp/GitHub:alice%40example.com?secret=JBSWY3DPEHPK3PXP"
            + "&issuer=GitHub&algorithm=SHA256&digits=8&period=60"
        switch TOTPSupport.parse(link) {
        case .success(let imported):
            suite.expect(imported.name == "alice@example.com",
                         "a percent-encoded account name is decoded")
            suite.expect(imported.issuer == "GitHub", "the issuer parameter is kept")
            suite.expect(imported.algorithm == .sha256, "the algorithm parameter is read")
            suite.expect(imported.digits == 8, "the digit count is read")
            suite.expect(imported.period == 60, "the period is read")
            suite.expect(imported.secret.count == 10, "the secret is decoded")
        case .failure(let error):
            suite.expect(false, "a complete setup link parses, got \(error)")
        }

        func check(_ raw: String, _ label: String, _ expectation: (TOTPImportedAccount) -> Bool) {
            switch TOTPSupport.parse(raw) {
            case .success(let imported):
                suite.expect(expectation(imported), label)
            case .failure(let error):
                suite.expect(false, "\(label): \(error)")
            }
        }
        check("otpauth://totp/ACME%20Co:bob?secret=JBSWY3DPEHPK3PXP",
              "the label's issuer prefix is decoded") {
            $0.issuer == "ACME Co" && $0.name == "bob"
        }
        check("otpauth://totp/alice?secret=JBSWY3DPEHPK3PXP",
              "a label without an issuer is the account name") {
            $0.name == "alice" && $0.issuer.isEmpty
        }
        check("otpauth://totp/Label:alice?secret=JBSWY3DPEHPK3PXP&issuer=Query",
              "the issuer parameter overrides the label prefix") {
            $0.issuer == "Query" && $0.name == "alice"
        }
        check("otpauth://totp/IssuerOnly?secret=JBSW-Y3DP EHPK-3PXP",
              "spaces and hyphens in the secret are accepted") {
            $0.name == "IssuerOnly"
                && $0.secret == Data([0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x21,
                                      0xde, 0xad, 0xbe, 0xef])
        }
        check("otpauth://totp/a?secret=JBSWY3DPEHPK3PXP&image=https%3A%2F%2Fexample.com",
              "unknown parameters are ignored") { $0.name == "a" }
        check("otpauth://totp/%E4%BE%8B%E5%AD%90:alice?secret=JBSWY3DPEHPK3PXP",
              "non-ASCII labels survive percent decoding") { $0.issuer == "例子" }
        check("otpauth://totp/a?secret=JBSWY3DPEHPK3PXP&algorithm=sha-1",
              "the hyphenated algorithm spelling is accepted") { $0.algorithm == .sha1 }
        check("otpauth://totp/a?secret=JBSWY3DPEHPK3PXP&period=1",
              "the lowest allowed period is accepted") { $0.period == 1 }

        let failures: [(String, TOTPError)] = [
            ("", .notOTPAuth),
            ("https://example.com/totp", .notOTPAuth),
            ("otpauth://hotp/a?secret=JBSWY3DPEHPK3PXP", .unsupportedType),
            ("otpauth://totp/a", .missingSecret),
            ("otpauth://totp/a?secret=", .missingSecret),
            ("otpauth://totp/a?secret=JBSWY3D0", .invalidSecret),
            ("otpauth://totp/a?secret=AA", .invalidSecret),
            ("otpauth://totp/a?secret=JBSWY3DPEHPK3PXP&digits=7", .invalidDigits),
            ("otpauth://totp/a?secret=JBSWY3DPEHPK3PXP&digits=x", .invalidDigits),
            ("otpauth://totp/a?secret=JBSWY3DPEHPK3PXP&period=0", .invalidPeriod),
            ("otpauth://totp/a?secret=JBSWY3DPEHPK3PXP&period=3601", .invalidPeriod),
            ("otpauth://totp/a?secret=JBSWY3DPEHPK3PXP&period=x", .invalidPeriod),
            ("otpauth://totp/a?secret=JBSWY3DPEHPK3PXP&algorithm=MD5", .invalidAlgorithm),
            ("otpauth://totp/?secret=JBSWY3DPEHPK3PXP", .invalidLabel),
            ("otpauth://totp/a?secret=JBSWY3DPEHPK3PXP&secret=JBSWY3DPEHPK3PXP", .malformed),
            ("otpauth://totp/a?secret=JBSWY3DPEHPK3PXP&period=30&period=60", .malformed),
        ]
        for (raw, expected) in failures {
            switch TOTPSupport.parse(raw) {
            case .success:
                suite.expect(false, "\(raw.debugDescription) should fail with \(expected)")
            case .failure(let error):
                suite.expect(error == expected,
                             "\(raw.debugDescription) fails with \(expected), got \(error)")
            }
        }

        suite.expect(TOTPSupport.parse(String(repeating: "a", count: 5000)).failureIsMalformed,
                     "an oversized link is refused before URL parsing")

        suite.expect(TOTPSupport.sanitizeLabel("  a\u{0007}b\n  ") == "ab",
                     "control characters and surrounding whitespace are dropped from labels")
        let long = String(repeating: "x", count: 500)
        suite.expect(TOTPSupport.sanitizeLabel(long).count == TOTPAccount.maximumNameLength,
                     "an overlong label is capped")
        suite.expect(TOTPSupport.validatedName("", issuer: "") == nil,
                     "an account with neither name nor issuer is refused")
        suite.expect(TOTPSupport.validatedName("", issuer: "GitHub") == "GitHub",
                     "an issuer alone becomes the display name")
    }

    // MARK: - Service

    private static func service(_ suite: TestSuite) {
        let domain = "com.tina.tests.totp.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: domain) else {
            suite.expect(false, "the isolated preferences domain could not be opened")
            return
        }
        defer { defaults.removePersistentDomain(forName: domain) }

        let store = MemoryStore()
        let service = TOTPAuthenticatorService(defaults: defaults, store: store)
        service.load()
        suite.expect(service.accounts.isEmpty, "a fresh install has no accounts")

        let secretText = TOTPSupport.base32Encode(bytes("12345678901234567890"))
        let added = service.add(name: "GitHub", issuer: "GitHub", secretText: secretText,
                                algorithm: .sha1, digits: 6, period: 30)
        guard case .success(let account) = added else {
            suite.expect(false, "a valid manual entry is added")
            return
        }
        suite.expect(service.accounts.count == 1, "the account is listed")
        suite.expect(store.values[account.id] == bytes("12345678901234567890"),
                     "the secret is written to the secret store")
        suite.expect(service.code(for: account, at: date(59)) == "287082",
                     "the saved account produces the RFC code")
        suite.expect(service.secondsRemaining(for: account, at: date(59)) == 1,
                     "the saved account reports its countdown")

        let reloaded = TOTPAuthenticatorService(defaults: defaults, store: store)
        reloaded.load()
        suite.expect(reloaded.accounts.map(\.id) == [account.id],
                     "metadata survives a reload")
        suite.expect(reloaded.code(for: account, at: date(59)) == "287082",
                     "the secret is read back from the store")

        suite.expect(service.rename(account.id, name: "Work", issuer: "Acme"),
                     "renaming a valid label succeeds")
        suite.expect(service.accounts.first?.name == "Work"
                        && service.accounts.first?.issuer == "Acme",
                     "the renamed labels are kept")
        suite.expect(!service.rename(account.id, name: "", issuer: ""),
                     "an empty rename is refused")

        let second = TOTPImportedAccount(name: "Second", issuer: "", secret: bytes("second-secret-value"),
                                         algorithm: .sha1, digits: 6, period: 30)
        _ = service.add(second)
        suite.expect(service.accounts.count == 2, "a second account is listed")
        service.move(account.id, by: 1)
        suite.expect(service.accounts.last?.id == account.id, "moving down reorders the list")
        service.move(account.id, by: 10)
        suite.expect(service.accounts.last?.id == account.id,
                     "a move past the end leaves the order alone")
        service.move(account.id, by: -1)
        suite.expect(service.accounts.first?.id == account.id, "moving up reorders the list")

        let failingStore = MemoryStore()
        failingStore.failSaves = true
        let failingDomain = "com.tina.tests.totp.failing.\(UUID().uuidString)"
        guard let failingDefaults = UserDefaults(suiteName: failingDomain) else {
            suite.expect(false, "the isolated failing-preferences domain could not be opened")
            return
        }
        defer { failingDefaults.removePersistentDomain(forName: failingDomain) }
        let failing = TOTPAuthenticatorService(defaults: failingDefaults, store: failingStore)
        failing.load()
        switch failing.add(name: "Nope", issuer: "", secretText: secretText,
                           algorithm: .sha1, digits: 6, period: 30) {
        case .failure(.storageFailed):
            suite.expect(failing.accounts.isEmpty,
                         "a failed Keychain write leaves no half-saved account")
        case .failure(let error):
            suite.expect(false, "a failed Keychain write reports storageFailed, got \(error)")
        case .success:
            suite.expect(false, "a failed Keychain write must not report success")
        }

        for (text, expected) in [("", TOTPError.missingSecret),
                                 ("not-base32!", TOTPError.invalidSecret),
                                 ("AA", TOTPError.invalidSecret)] {
            switch service.add(name: "Bad", issuer: "", secretText: text,
                               algorithm: .sha1, digits: 6, period: 30) {
            case .failure(let error):
                suite.expect(error == expected, "manual entry \(text.debugDescription) reports \(expected)")
            case .success:
                suite.expect(false, "manual entry \(text.debugDescription) must be refused")
            }
        }
        suite.expect(service.add(name: "", issuer: "", secretText: secretText,
                                 algorithm: .sha1, digits: 6, period: 30).failureIsInvalidName,
                     "a nameless entry is refused")
        suite.expect(service.add(name: "Bad", issuer: "", secretText: secretText,
                                 algorithm: .sha1, digits: 7, period: 30).failureIsInvalidDigits,
                     "an invalid digit count is refused")
        suite.expect(service.add(name: "Bad", issuer: "", secretText: secretText,
                                 algorithm: .sha1, digits: 6, period: 0).failureIsInvalidPeriod,
                     "an invalid period is refused")

        // An account whose Keychain item disappears is reported, not hidden.
        store.values[account.id] = nil
        let orphan = TOTPAuthenticatorService(defaults: defaults, store: store)
        orphan.load()
        guard let orphanAccount = orphan.accounts.first(where: { $0.id == account.id }) else {
            suite.expect(false, "the orphaned account is still listed")
            return
        }
        suite.expect(orphan.code(for: orphanAccount, at: date(60)) == nil,
                     "an account without its secret produces no code")
        suite.expect(!orphan.hasSecret(for: orphanAccount.id),
                     "the missing secret is reported")

        // Put the secret back so the delete case starts from a complete row.
        store.values[account.id] = bytes("12345678901234567890")
        store.failDeletes = true
        service.delete(account.id)
        suite.expect(store.values[account.id] != nil
                        && service.accounts.contains { $0.id == account.id },
                     "a failed secret deletion keeps the row instead of orphaning the secret")
        store.failDeletes = false
        service.delete(account.id)
        suite.expect(store.values[account.id] == nil, "deleting removes the stored secret")
        suite.expect(!service.accounts.contains { $0.id == account.id },
                     "deleting removes the row")

        // Absent or damaged metadata decodes to nothing instead of throwing.
        suite.expect(TOTPAuthenticatorService.decodeAccounts(nil).isEmpty,
                     "missing metadata is an empty list")
        suite.expect(TOTPAuthenticatorService.decodeAccounts("not json").isEmpty,
                     "damaged metadata is an empty list")
        let duplicate = TOTPAccount(id: account.id, name: "One")
        let encoded = (try? JSONEncoder().encode([duplicate, duplicate]))
            .flatMap { String(data: $0, encoding: .utf8) }
        suite.expect(TOTPAuthenticatorService.decodeAccounts(encoded).count == 1,
                     "duplicate ids are collapsed on load")
        let invalid = TOTPAccount(name: "Bad", digits: 5)
        let invalidEncoded = (try? JSONEncoder().encode([invalid]))
            .flatMap { String(data: $0, encoding: .utf8) }
        suite.expect(TOTPAuthenticatorService.decodeAccounts(invalidEncoded).isEmpty,
                     "a malformed account is dropped on load")
    }

    // MARK: - Display

    private static func display(_ suite: TestSuite) {
        suite.expect(TOTPSupport.grouped("123456") == "123 456",
                     "six-digit codes are split in half")
        suite.expect(TOTPSupport.grouped("12345678") == "1234 5678",
                     "eight-digit codes are split in half")
        suite.expect(TOTPSupport.grouped("1") == "1", "a single digit is untouched")
        suite.expect(TOTPSupport.maskedCode(digits: 6) == "••• •••",
                     "the mask follows the digit count")
        suite.expect(TOTPSupport.maskedCode(digits: 8) == "•••• ••••",
                     "an eight-digit mask has four dots per half")
        suite.expect(TOTPSupport.maskedCode(digits: 0) == "•",
                     "a nonsensical digit count still yields a mask")

        suite.expect(TOTPAlgorithm.allCases.map(\.rawValue) == ["SHA1", "SHA256", "SHA512"],
                     "the algorithm list is stable")
        suite.expect(TOTPAlgorithm(linkValue: "sha-512") == .sha512,
                     "the hyphenated link spelling maps to SHA512")

        let account = TOTPAccount(name: "GitHub", issuer: "GitHub")
        let roundTrip = (try? JSONEncoder().encode(account))
            .flatMap { try? JSONDecoder().decode(TOTPAccount.self, from: $0) }
        suite.expect(roundTrip == account, "the account model round trips through JSON")
        suite.expect(!String(data: (try? JSONEncoder().encode(account)) ?? Data(), encoding: .utf8)!
                        .lowercased().contains("secret"),
                     "the encoded account model never mentions a secret")
    }
}

private extension Result where Success == TOTPImportedAccount, Failure == TOTPError {
    var failureIsMalformed: Bool {
        if case .failure(.malformed) = self { return true }
        return false
    }
}

private extension Result where Success == TOTPAccount, Failure == TOTPError {
    var failureIsInvalidName: Bool {
        if case .failure(.invalidName) = self { return true }
        return false
    }

    var failureIsInvalidDigits: Bool {
        if case .failure(.invalidDigits) = self { return true }
        return false
    }

    var failureIsInvalidPeriod: Bool {
        if case .failure(.invalidPeriod) = self { return true }
        return false
    }
}
