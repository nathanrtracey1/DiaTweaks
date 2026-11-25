import Foundation
import Security
import LocalAuthentication

enum ProviderSecrets {
    static func query(_ id: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.diapatches.chat-model-providers",
         kSecAttrAccount as String: id]
    }
    static func read(_ id: String) throws -> String? {
        try ProviderSecretsCache.read(id) { try readStored(id) }
    }
    static func available(_ id: String) -> Bool { ProviderSecretsCache.available(id) }
    static func write(_ id: String, _ key: String?) throws {
        let value = key.flatMap { $0.isEmpty ? nil : $0 }
        try ProviderSecretsCache.write(id, value: value) { try writeStored(id, value) }
    }
    private static func readStored(_ id: String) throws -> String? {
        var query = query(id)
        query[kSecReturnData as String] = true
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = value as? Data, let key = String(data: data, encoding: .utf8) else {
            throw ProviderError.keychain(status)
        }
        return key
    }
    private static func writeStored(_ id: String, _ key: String?) throws {
        let query = query(id)
        guard let key, !key.isEmpty else {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw ProviderError.keychain(status) }
            return
        }
        let data = Data(key.utf8)
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw ProviderError.keychain(status) }
    }
}
