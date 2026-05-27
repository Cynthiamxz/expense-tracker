// KeychainHelper.swift
// Responsibility: Low-level wrapper around the iOS Keychain (Security framework)
//                 for storing, reading, and deleting string values. The only
//                 sanctioned storage for OAuth tokens — never use UserDefaults.
// Depends on: Security framework
// Used by: GmailAuthService (access_token, refresh_token, expiry Date, email)

import Foundation
import Security

struct KeychainHelper {
    private static let service = Bundle.main.bundleIdentifier ?? "com.cynthiamxz.ExpenseTracker"

    // Stores a string value under the given key. Overwrites silently if the key exists.
    // Returns true on success, false if the Keychain rejected the write.
    @discardableResult
    static func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Attribute-only query (no value) used for both Add and Update.
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]

        // Try to add first.
        var addQuery = query
        addQuery[kSecValueData] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        if addStatus == errSecSuccess {
            return true
        }

        // Item already exists — update the value in place.
        if addStatus == errSecDuplicateItem {
            let update: [CFString: Any] = [kSecValueData: data]
            let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
            return updateStatus == errSecSuccess
        }

        return false
    }

    // Returns the string stored under `key`, or nil if absent or unreadable.
    static func read(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }

        return string
    }

    // Removes the item stored under `key`. Safe to call when the key doesn't exist.
    static func delete(forKey key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        // errSecItemNotFound is not an error here — the goal is the item not existing.
        assert(status == errSecSuccess || status == errSecItemNotFound,
               "Keychain delete failed with status \(status)")
    }
}
