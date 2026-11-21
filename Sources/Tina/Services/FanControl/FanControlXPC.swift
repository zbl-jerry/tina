// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation
#if TINA_DEVELOPMENT
import Security
import CryptoKit
#endif

enum FanControlIdentifiers {
    static let teamID = "3D485NHW29"

    #if TINA_DEVELOPMENT
    static let appBundleID = "com.tina.utils.dev"
    #else
    static let appBundleID = "com.tina.utils"
    #endif

    static let helperID = "\(appBundleID).fan-control"
    static let plistName = "\(helperID).plist"

    static var appCodeRequirement: String {
        #if TINA_DEVELOPMENT
        guard let hash = self.currentLeafCertificateSHA1() else {
            return "identifier \"\(appBundleID)\" and certificate leaf = H\"0000000000000000000000000000000000000000\""
        }
        return "identifier \"\(appBundleID)\" and certificate leaf = H\"\(hash)\""
        #else
        return "anchor apple generic and certificate leaf[subject.OU] = \"\(teamID)\" and identifier \"\(appBundleID)\""
        #endif
    }

    static var helperCodeRequirement: String {
        #if TINA_DEVELOPMENT
        guard let hash = self.currentLeafCertificateSHA1() else {
            return "identifier \"\(helperID)\" and certificate leaf = H\"0000000000000000000000000000000000000000\""
        }
        return "identifier \"\(helperID)\" and certificate leaf = H\"\(hash)\""
        #else
        return "anchor apple generic and certificate leaf[subject.OU] = \"\(teamID)\" and identifier \"\(helperID)\""
        #endif
    }

    #if TINA_DEVELOPMENT
    private static func currentLeafCertificateSHA1() -> String? {
        var dynamicCode: SecCode?
        guard SecCodeCopySelf([], &dynamicCode) == errSecSuccess,
              let selfCode = dynamicCode else {
            return nil
        }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(selfCode, [], &staticCode) == errSecSuccess,
              let staticSelfCode = staticCode else {
            return nil
        }

        var signingInfo: CFDictionary?
        guard SecCodeCopySigningInformation(staticSelfCode, SecCSFlags(rawValue: kSecCSSigningInformation), &signingInfo) == errSecSuccess,
              let info = signingInfo as? [String: Any] else {
            return nil
        }

        guard let certificates = info[kSecCodeInfoCertificates as String] as? [SecCertificate],
              let leaf = certificates.first else {
            return nil
        }

        let data = SecCertificateCopyData(leaf) as Data
        let digest = Insecure.SHA1.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    #endif
}

/// The protocol of Tina's one privileged helper. The service identity keeps
/// its `fan-control` name because macOS has already registered it on existing
/// installs; the charge limit is a second, separately owned capability of the
/// same root process, with its own lock, marker and teardown.
@objc protocol FanControlXPCProtocol {
    func status(withReply reply: @escaping (Data) -> Void)
    func startMaximumCooling(withReply reply: @escaping (Data) -> Void)
    func applyConfiguration(_ configuration: Data, withReply reply: @escaping (Data) -> Void)
    func heartbeat(withReply reply: @escaping (Data) -> Void)
    func restoreAutomatic(withReply reply: @escaping (Data) -> Void)
    func chargeLimitStatus(withReply reply: @escaping (Data) -> Void)
    func applyChargeLimit(_ configuration: Data, withReply reply: @escaping (Data) -> Void)
    func restoreCharging(withReply reply: @escaping (Data) -> Void)
}

enum FanControlIPC {
    static func encode(_ response: FanControlResponse) -> Data {
        // Every value in this closed response model is JSON encodable. Keeping
        // one deterministic fallback avoids ever violating the XPC reply shape.
        (try? JSONEncoder().encode(response))
            ?? Data(#"{"succeeded":false,"snapshot":{"fans":[],"isCooling":false},"error":"controlFailed"}"#.utf8)
    }

    static func decode(_ data: Data) -> FanControlResponse? {
        try? JSONDecoder().decode(FanControlResponse.self, from: data)
    }

    static func encode(_ configuration: FanControlConfiguration) -> Data? {
        try? JSONEncoder().encode(configuration)
    }

    static func decodeConfiguration(_ data: Data) -> FanControlConfiguration? {
        guard let configuration = try? JSONDecoder().decode(FanControlConfiguration.self,
                                                              from: data),
              FanControlPolicy.validConfiguration(configuration) else { return nil }
        return configuration
    }
}
