import Foundation
import Security

/// The TypeSafe API key as a generic password in the login keychain.
enum KeychainStore {
    private static var item: [String: Any] { [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "dev.gomareli.findsfsymbols",
        kSecAttrAccount as String: "typesafe-api-key",
    ] }

    static func read() -> String? {
        var query = item
        query[kSecReturnData as String] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ key: String) -> Bool {
        SecItemDelete(item as CFDictionary)
        var attributes = item
        attributes[kSecValueData as String] = Data(key.utf8)
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        SecItemDelete(item as CFDictionary)
    }
}
