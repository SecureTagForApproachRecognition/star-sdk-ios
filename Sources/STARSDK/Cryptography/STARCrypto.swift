import CommonCrypto
import Foundation

/// An implementation of the STAR algorithm
class STARCrypto: STARCryptoProtocol {
    /// The interval for the token regeneration
    private let interval: Int32 = 60
    /// A tag to retreive the generated key from the keychain
    private let tag = "ch.ubique.starsdk.key"

    /// Initialize the algorithm. Can throw if a key cannot be generated
    init() throws {
        switch secretKey {
        case .success:
            break
        case .notFound:
            try createKey()
        case let .error(error):
            throw error
        }
    }

    func newTOTP() throws -> Data {
        let key = try getSecretKey()
        var counter = Int32(Date().timeIntervalSince1970) / interval
        let timestamp = Data(bytes: &counter, count: MemoryLayout<Int32>.size)
        let hmacValue = hmac(msg: timestamp, key: key)
        return timestamp + hmacValue
    }

    func validate(key: Data, star: Data) -> Bool {
        let timestamp = star[0 ..< MemoryLayout<Int32>.size]
        let expectedHMAC = star[MemoryLayout<Int32>.size...]
        let calculatedHMAC = hmac(msg: timestamp, key: key)
        return expectedHMAC == calculatedHMAC
    }

    func getSecretKey() throws -> Data {
        switch secretKey {
        case let .success(key):
            return key
        case .notFound:
            throw STARTracingErrors.CryptographyError(error: "Key not found")
        case let .error(error):
            throw error
        }
    }

    private enum SecretKeyReturn {
        case success(Data)
        case notFound
        case error(Error)
    }

    /// Retreive the secret key
    private var secretKey: SecretKeyReturn {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            return .notFound
        }
        guard status == errSecSuccess else {
            return .error(STARTracingErrors.CryptographyError(error: "Cannot access the keychain \(status)"))
        }
        return .success((item as! CFData) as Data)
    }

    /// Create a random secret key
    private func createKey() throws {
        guard let randomKey = generateRandomKey() else {
            throw STARTracingErrors.CryptographyError(error: "Cannot create random key")
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: tag,
            kSecValueData as String: randomKey,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw STARTracingErrors.CryptographyError(error: "Cannot store key in keychain")
        }
    }

    func reset() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tag,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw STARTracingErrors.CryptographyError(error: "Cannot remove key from keychain")
        }
    }

    /// Generate a random key
    private func generateRandomKey() -> Data? {
        var keyData = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, Int(CC_SHA256_DIGEST_LENGTH), $0.baseAddress!)
        }
        guard result == errSecSuccess else {
            return nil
        }
        return keyData
    }

    /// Perform an HMAC function on a message using a secret key
    /// - Parameters:
    ///   - msg: The message to be hashed
    ///   - key: The key to use for the hash
    private func hmac(msg: Data, key: Data) -> Data {
        var macData = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        macData.withUnsafeMutableBytes { macBytes in
            msg.withUnsafeBytes { msgBytes in
                key.withUnsafeBytes { keyBytes in
                    guard let keyAddress = keyBytes.baseAddress,
                        let msgAddress = msgBytes.baseAddress,
                        let macAddress = macBytes.baseAddress
                    else { return }
                    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                           keyAddress, key.count, msgAddress,
                           msg.count, macAddress)
                    return
                }
            }
        }
        return macData
    }
}
