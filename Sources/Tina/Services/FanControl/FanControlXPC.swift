// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

enum FanControlIdentifiers {
    #if TINA_DEVELOPMENT
    static let appBundleID = "com.tina.utils.dev"
    #else
    static let appBundleID = "com.tina.utils"
    #endif

    static let helperID = "\(appBundleID).fan-control"
    static let plistName = "\(helperID).plist"

    /// Releases are signed with the project's own certificate rather than a
    /// Developer ID, so both peers pin the certificate that signed this
    /// process. A different or absent certificate fails closed.
    static var appCodeRequirement: String {
        CodeSigningIdentity.requirement(identifier: appBundleID)
    }

    static var helperCodeRequirement: String {
        CodeSigningIdentity.requirement(identifier: helperID)
    }
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
