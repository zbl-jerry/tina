// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation
import Security

/// Secrets live in the login keychain as generic passwords, one item per
/// account. The item is device-only and unlocked-only: it is never synced to
/// iCloud, never leaves this Mac in a backup, and is not readable while the
/// screen is locked. The service name follows the bundle id so the Developer
/// build keeps a separate set from the official app.
struct TOTPKeychainStore: TOTPSecretStore {
    static var defaultService: String {
        "\(Bundle.main.bundleIdentifier ?? "com.tina.utils").totp"
    }

    let service: String

    init(service: String = TOTPKeychainStore.defaultService) {
        self.service = service
    }

    private func baseQuery(for id: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecAttrSynchronizable as String: false,
        ]
    }

    func secret(for id: UUID) -> Data? {
        var query = baseQuery(for: id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return data
    }

    func save(_ secret: Data, for id: UUID) -> Bool {
        let query = baseQuery(for: id)
        let attributes: [String: Any] = [kSecValueData as String: secret]
        let updated = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updated == errSecSuccess { return true }
        guard updated == errSecItemNotFound else { return false }

        var insertion = query
        insertion[kSecValueData as String] = secret
        insertion[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(insertion as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    func delete(_ id: UUID) -> Bool {
        let status = SecItemDelete(baseQuery(for: id) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
