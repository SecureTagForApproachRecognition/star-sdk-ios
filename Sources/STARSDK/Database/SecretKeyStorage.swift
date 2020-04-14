//

import Foundation

enum KeychainError: Error {
    case notFound
    case cannotAccess
}

protocol SecretKeyStorageProtocol {
    func get() throws -> [SecretKey]
    func set(_ object: [SecretKey]) throws
    func removeAllObject()
}

class SecretKeyStorage: SecretKeyStorageProtocol {
    static let shared = SecretKeyStorage()

    private let key: String = "ch.ubique.keylist"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {}

    func get() throws -> [SecretKey] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            throw KeychainError.notFound
        }
        guard status == errSecSuccess else {
            throw KeychainError.cannotAccess
        }
        let data = (item as! CFData) as Data
        return try decoder.decode([SecretKey].self, from: data)
    }

    func set(_ object: [SecretKey]) throws {
        let data = try encoder.encode(object)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    func removeAllObject() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
