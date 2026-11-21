// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import CryptoKit
import Foundation

/// A standard time-based one-time password algorithm (RFC 6238). The raw
/// values match the names a setup link uses, so parsing and display read from
/// one place.
enum TOTPAlgorithm: String, Codable, CaseIterable, Identifiable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"

    var id: String { rawValue }

    /// Accepts the spellings providers actually write, including the
    /// hyphenated form some setup pages use.
    init?(linkValue: String) {
        let normalized = linkValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: "-", with: "")
        self.init(rawValue: normalized)
    }
}

/// One saved account. The secret is deliberately absent: it lives in the
/// Keychain under the account's id, so this model can be encoded into the
/// preferences file without carrying the credential with it.
struct TOTPAccount: Identifiable, Codable, Equatable {
    static let maximumNameLength = 120
    static let allowedDigits = [6, 8]
    static let allowedPeriodRange = 1...3600

    var id: UUID
    var name: String
    var issuer: String
    var algorithm: TOTPAlgorithm
    var digits: Int
    var period: Int

    init(id: UUID = UUID(),
         name: String,
         issuer: String = "",
         algorithm: TOTPAlgorithm = .sha1,
         digits: Int = 6,
         period: Int = 30) {
        self.id = id
        self.name = name
        self.issuer = issuer
        self.algorithm = algorithm
        self.digits = digits
        self.period = period
    }

    /// What the row shows when there is no issuer to sit underneath it.
    var displayName: String {
        name.isEmpty ? issuer : name
    }

    var isWellFormed: Bool {
        let cleanName = TOTPSupport.sanitizeLabel(name)
        let cleanIssuer = TOTPSupport.sanitizeLabel(issuer)
        return !(cleanName.isEmpty && cleanIssuer.isEmpty)
            && cleanName.count <= Self.maximumNameLength
            && cleanIssuer.count <= Self.maximumNameLength
            && Self.allowedDigits.contains(digits)
            && Self.allowedPeriodRange.contains(period)
    }
}

/// The parts of a parsed `otpauth://totp/...` link, before an account id is
/// assigned. `secret` stays in memory only for the length of the add flow.
struct TOTPImportedAccount: Equatable {
    let name: String
    let issuer: String
    let secret: Data
    let algorithm: TOTPAlgorithm
    let digits: Int
    let period: Int

    var account: TOTPAccount {
        TOTPAccount(name: name, issuer: issuer,
                    algorithm: algorithm, digits: digits, period: period)
    }
}

/// Why a setup link or a manual entry could not be accepted. No case carries
/// the secret or the link text: errors are shown to the person and may end up
/// in a log, and neither belongs there.
enum TOTPError: Error, Equatable {
    case notOTPAuth
    case unsupportedType
    case missingSecret
    case invalidSecret
    case invalidDigits
    case invalidPeriod
    case invalidAlgorithm
    case invalidLabel
    case malformed
    case invalidName
    case storageFailed
}

/// Where secrets live. The Keychain implementation is app-only; the tests use
/// an in-memory double, so code generation runs without touching the system
/// keychain.
protocol TOTPSecretStore {
    func secret(for id: UUID) -> Data?
    func save(_ secret: Data, for id: UUID) -> Bool
    /// False only when the item may still exist. The row is kept in that case,
    /// so the list never claims a secret was removed while it is on the Mac.
    @discardableResult
    func delete(_ id: UUID) -> Bool
}

/// Everything about the authenticator that can be decided without a window or
/// a keychain: Base32, the `otpauth` grammar and the RFC 6238 calculation.
/// The service adds persistence around it.
enum TOTPSupport {
    static let defaultDigits = 6
    static let defaultPeriod = 30
    static let maximumSecretBytes = 128
    static let minimumSecretBytes = 5
    static let maximumLinkLength = 4096

    private static let recognizedParameters: Set<String> = [
        "secret", "issuer", "algorithm", "digits", "period",
    ]

    private static let base32Alphabet: [Character: UInt8] = {
        var map: [Character: UInt8] = [:]
        for (index, scalar) in "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".unicodeScalars.enumerated() {
            map[Character(scalar)] = UInt8(index)
        }
        return map
    }()

    // MARK: - Base32 (RFC 4648)

    /// Decodes a Base32 secret as providers write it in setup links. Case,
    /// spaces and hyphens are tolerated because people paste keys by hand;
    /// padding is accepted only at the end. Nil means the text is not Base32.
    static func base32Decode(_ input: String) -> Data? {
        var cleaned = String()
        cleaned.reserveCapacity(input.count)
        var sawPadding = false
        for character in input.uppercased() {
            if character.isWhitespace || character == "-" { continue }
            if character == "=" {
                sawPadding = true
                continue
            }
            if sawPadding { return nil }
            cleaned.append(character)
        }
        guard !cleaned.isEmpty, cleaned.count <= maximumLinkLength else { return nil }

        var buffer: UInt32 = 0
        var bitCount = 0
        var output = Data()
        output.reserveCapacity(cleaned.count * 5 / 8)
        for character in cleaned {
            guard let value = base32Alphabet[character] else { return nil }
            buffer = (buffer << 5) | UInt32(value)
            bitCount += 5
            if bitCount >= 8 {
                bitCount -= 8
                output.append(UInt8((buffer >> UInt32(bitCount)) & 0xff))
                buffer &= bitCount == 0 ? 0 : (1 << UInt32(bitCount)) - 1
            }
        }
        return output.isEmpty ? nil : output
    }

    /// Encodes bytes as unpadded Base32. Used only to put a parsed link's
    /// secret back into the manual form, so the person can review what will be
    /// saved.
    static func base32Encode(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }
        var output = String()
        output.reserveCapacity((data.count * 8 + 4) / 5)
        var buffer: UInt32 = 0
        var bitCount = 0
        for byte in data {
            buffer = (buffer << 8) | UInt32(byte)
            bitCount += 8
            while bitCount >= 5 {
                bitCount -= 5
                let index = Int((buffer >> UInt32(bitCount)) & 0x1f)
                output.append(Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")[index])
            }
            buffer &= bitCount == 0 ? 0 : (1 << UInt32(bitCount)) - 1
        }
        if bitCount > 0 {
            let index = Int((buffer << UInt32(5 - bitCount)) & 0x1f)
            output.append(Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")[index])
        }
        return output
    }

    // MARK: - RFC 6238

    /// The number of whole time steps since the Unix epoch.
    static func counter(at date: Date, period: Int) -> UInt64 {
        let cycle = max(1, period)
        let seconds = date.timeIntervalSince1970
        guard seconds > 0 else { return 0 }
        return UInt64(floor(seconds / Double(cycle)))
    }

    /// Whole seconds left in the current step. The value is `period` at the
    /// instant a step begins, so a countdown never shows zero while the code
    /// on screen still works.
    static func secondsRemaining(at date: Date, period: Int) -> Int {
        let cycle = max(1, period)
        let seconds = max(0, floor(date.timeIntervalSince1970))
        let elapsed = Int(seconds.truncatingRemainder(dividingBy: Double(cycle)))
        return cycle - elapsed
    }

    /// Generates the code for a counter with HMAC and dynamic truncation, the
    /// calculation RFC 6238 specifies on top of RFC 4226.
    static func code(secret: Data, counter: UInt64, digits: Int, algorithm: TOTPAlgorithm) -> String {
        guard !secret.isEmpty, let modulus = modulus(for: digits) else { return "" }
        var bigEndianCounter = counter.bigEndian
        let message = withUnsafeBytes(of: &bigEndianCounter) { Data($0) }
        let key = SymmetricKey(data: secret)
        let mac: Data
        switch algorithm {
        case .sha1:
            mac = Data(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: key))
        case .sha256:
            mac = Data(HMAC<SHA256>.authenticationCode(for: message, using: key))
        case .sha512:
            mac = Data(HMAC<SHA512>.authenticationCode(for: message, using: key))
        }
        guard mac.count >= 20 else { return "" }
        let offset = Int(mac[mac.count - 1] & 0x0f)
        guard offset + 4 <= mac.count else { return "" }
        let value = (UInt32(mac[offset] & 0x7f) << 24)
            | (UInt32(mac[offset + 1]) << 16)
            | (UInt32(mac[offset + 2]) << 8)
            | UInt32(mac[offset + 3])
        let number = UInt64(value) % modulus
        let text = String(number)
        return String(repeating: "0", count: max(0, digits - text.count)) + text
    }

    static func code(secret: Data, at date: Date, digits: Int, period: Int,
                     algorithm: TOTPAlgorithm) -> String {
        code(secret: secret,
             counter: counter(at: date, period: period),
             digits: digits,
             algorithm: algorithm)
    }

    private static func modulus(for digits: Int) -> UInt64? {
        switch digits {
        case 6: return 1_000_000
        case 8: return 100_000_000
        default: return nil
        }
    }

    // MARK: - Display

    /// Splits a code in half for reading, as authenticator apps do. The
    /// clipboard receives the ungrouped digits.
    static func grouped(_ code: String) -> String {
        guard code.count > 1 else { return code }
        let middle = code.index(code.startIndex, offsetBy: code.count / 2)
        return code[..<middle] + " " + code[middle...]
    }

    /// The dots a row shows before the person reveals the code.
    static func maskedCode(digits: Int) -> String {
        let count = max(1, digits)
        guard count > 1 else { return "•" }
        let half = count / 2
        let left = String(repeating: "•", count: half)
        let right = String(repeating: "•", count: count - half)
        return left + " " + right
    }

    // MARK: - Setup links

    /// Parses the `otpauth://totp/...` link a service shows next to its QR
    /// code. Unknown parameters are ignored for forward compatibility; a
    /// duplicated parameter is refused, because silently choosing one would
    /// hide that the two disagree.
    static func parse(_ raw: String) -> Result<TOTPImportedAccount, TOTPError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.notOTPAuth) }
        guard trimmed.count <= maximumLinkLength else { return .failure(.malformed) }
        guard let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "otpauth"
        else { return .failure(.notOTPAuth) }
        guard components.host?.lowercased() == "totp" else { return .failure(.unsupportedType) }

        var parameters: [String: String] = [:]
        for item in components.queryItems ?? [] {
            let key = item.name.lowercased()
            guard recognizedParameters.contains(key) else { continue }
            guard parameters[key] == nil else { return .failure(.malformed) }
            parameters[key] = item.value ?? ""
        }

        guard let rawSecret = parameters["secret"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawSecret.isEmpty
        else { return .failure(.missingSecret) }
        guard let secret = base32Decode(rawSecret),
              secret.count >= minimumSecretBytes,
              secret.count <= maximumSecretBytes
        else { return .failure(.invalidSecret) }

        let encodedPath = components.percentEncodedPath
        let decodedPath = encodedPath.removingPercentEncoding ?? encodedPath
        var label = decodedPath
        if label.hasPrefix("/") { label.removeFirst() }

        var issuerFromLabel = ""
        var account = label
        if let colon = label.firstIndex(of: ":") {
            issuerFromLabel = String(label[..<colon])
            account = String(label[label.index(after: colon)...])
        }
        account = sanitizeLabel(account)
        issuerFromLabel = sanitizeLabel(issuerFromLabel)
        let issuerFromQuery = sanitizeLabel(parameters["issuer"] ?? "")
        let issuer = issuerFromQuery.isEmpty ? issuerFromLabel : issuerFromQuery
        let name = account.isEmpty ? issuer : account
        guard !name.isEmpty else { return .failure(.invalidLabel) }

        let algorithm: TOTPAlgorithm
        if let raw = parameters["algorithm"], !raw.isEmpty {
            guard let parsed = TOTPAlgorithm(linkValue: raw) else {
                return .failure(.invalidAlgorithm)
            }
            algorithm = parsed
        } else {
            algorithm = .sha1
        }

        let digits: Int
        if let raw = parameters["digits"], !raw.isEmpty {
            guard let parsed = Int(raw), TOTPAccount.allowedDigits.contains(parsed) else {
                return .failure(.invalidDigits)
            }
            digits = parsed
        } else {
            digits = defaultDigits
        }

        let period: Int
        if let raw = parameters["period"], !raw.isEmpty {
            guard let parsed = Int(raw),
                  TOTPAccount.allowedPeriodRange.contains(parsed)
            else { return .failure(.invalidPeriod) }
            period = parsed
        } else {
            period = defaultPeriod
        }

        return .success(TOTPImportedAccount(name: name, issuer: issuer, secret: secret,
                                           algorithm: algorithm, digits: digits, period: period))
    }

    /// Trims a label and drops control characters, which would otherwise be
    /// pasted into a row or a settings file. Length is capped so one link
    /// cannot make the list unusable.
    static func sanitizeLabel(_ raw: String) -> String {
        let filtered = raw.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        let text = String(String.UnicodeScalarView(filtered))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > TOTPAccount.maximumNameLength else { return text }
        return String(text.prefix(TOTPAccount.maximumNameLength))
    }

    /// Whether a manually typed name is usable. The secret is validated by the
    /// service through `base32Decode`, so both entry paths share one rule.
    static func validatedName(_ name: String, issuer: String) -> String? {
        let cleanName = sanitizeLabel(name)
        let cleanIssuer = sanitizeLabel(issuer)
        guard !(cleanName.isEmpty && cleanIssuer.isEmpty) else { return nil }
        return cleanName.isEmpty ? cleanIssuer : cleanName
    }
}
