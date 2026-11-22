// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import CryptoKit
import Foundation
import Security

/// The certificate that signed the running process.
///
/// Tina has no Developer ID certificate, so a code requirement cannot be
/// anchored with `anchor apple generic` or a team OU. Pinning the leaf
/// certificate instead ties the updater and the privileged helper to the
/// artifact they belong to: only code signed with the same certificate is
/// accepted. An unsigned (ad-hoc) process has no certificate at all, so its
/// placeholder digest matches nothing and every check fails closed.
enum CodeSigningIdentity {
    /// Lowercase hex SHA-1 of the leaf certificate that signed this process.
    /// The `codesign` requirement language compares `certificate leaf = H"…"`
    /// with exactly this digest.
    static func currentLeafCertificateSHA1() -> String? {
        var dynamicCode: SecCode?
        guard SecCodeCopySelf([], &dynamicCode) == errSecSuccess,
              let dynamicCode else { return nil }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(dynamicCode, [], &staticCode) == errSecSuccess,
              let staticCode else { return nil }

        var signingInfo: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode,
                                            SecCSFlags(rawValue: kSecCSSigningInformation),
                                            &signingInfo) == errSecSuccess,
              let info = signingInfo as? [String: Any],
              let certificates = info[kSecCodeInfoCertificates as String] as? [SecCertificate],
              let leaf = certificates.first else { return nil }

        let data = SecCertificateCopyData(leaf) as Data
        return Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Digest that requirements pin to. The all-zero fallback is deliberate:
    /// a process that cannot name its certificate must not accept anything.
    static var pinnedCertificateSHA1: String {
        currentLeafCertificateSHA1() ?? String(repeating: "0", count: 40)
    }

    /// A requirement matching the running process's certificate.
    static var pinnedCertificateRequirement: String {
        "certificate leaf = H\"\(pinnedCertificateSHA1)\""
    }

    /// A requirement matching `identifier`, signed by the same certificate.
    static func requirement(identifier: String) -> String {
        "identifier \"\(identifier)\" and \(pinnedCertificateRequirement)"
    }
}
