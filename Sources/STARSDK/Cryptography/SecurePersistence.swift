//
//  PersistenceManager.swift
//  epfl-ic-jlcv
//
//  Created by Loïc Gardiol on 29.03.20.
//  Copyright © 2020 Loïc Gardiol. All rights reserved.
//

import Foundation

class SecurePersistence {
    
    static let shared = SecurePersistence()
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init() {}
    
    func object<T : Decodable>(key: String) -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            return nil
        }
        guard status == errSecSuccess else {
            return nil
        }
        let data = (item as! CFData) as Data
        return try? self.decoder.decode(T.self, from: data)
    }
    
    func set<T : Encodable>(_ object: T?, key: String) {
        if let data = try? self.encoder.encode(object) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword as String,
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            ]
            SecItemAdd(query as CFDictionary, nil)
        }
    }
    
    func removeObject(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
