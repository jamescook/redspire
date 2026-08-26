import Foundation
import Security

/// Seam over Steam-credential storage so SteamCMDSession/the wizard UI can be
/// tested with an in-memory fake instead of the real macOS Keychain.
protocol CredentialStore {
    func listAccounts() -> [String]
    func password(for account: String) -> String?
    @discardableResult func save(password: String, for account: String) -> Bool
    @discardableResult func delete(account: String) -> Bool
}

/// Stores Steam usernames/passwords in the macOS Keychain, scoped to this
/// app's own service name. Strictly opt-in -- nothing is saved unless the
/// user checks "Remember this password". Reading a saved password triggers
/// the system's own Keychain-access prompt; this app never sees that gate,
/// it just gets denied or handed the bytes.
struct KeychainCredentialStore: CredentialStore {
    private let service = "com.jamescook.BattlespireLauncher.steamcmd"

    func listAccounts() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else { return [] }
        return items.compactMap { $0[kSecAttrAccount as String] as? String }.sorted()
    }

    func password(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func save(password: String, for account: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }
        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        // Overwrite cleanly rather than erroring on a duplicate item.
        SecItemDelete(identity as CFDictionary)
        var attributes = identity
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
