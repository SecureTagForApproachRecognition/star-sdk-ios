//

import Foundation
import CommonCrypto

public class Crypto {
    public static func sha256(_ data: Data) -> Data {
        var digest = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        digest.withUnsafeMutableBytes { (rawMutableBufferPointer) in
            let bufferPointer = rawMutableBufferPointer.bindMemory(to: UInt8.self)
            _ = data.withUnsafeBytes {
                CC_SHA256($0.baseAddress, UInt32(data.count), bufferPointer.baseAddress)
            }
        }
        return digest
    }

    /// Perform an HMAC function on a message using a secret key
    /// - Parameters:
    ///   - msg: The message to be hashed
    ///   - key: The key to use for the hash
    public static func hmac(msg: Data, key: Data) -> Data {
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


    class AESCTREncrypt {

        let keyData: Data
        let keyLength: Int
        let ivSize: Int

        var cryptLength: Int
        var options: CCOptions
        
        var numBytesEncrypted :size_t = 0

        init(keyData:Data) throws {
            self.keyData = keyData

            keyLength = keyData.count

            ivSize = kCCBlockSizeAES128;

            cryptLength = size_t(ivSize + 16 + kCCBlockSizeAES128)

            options   = CCOptions(kCCModeCTR)
        }

        func encrypt(data: Data) throws -> Data {

            var cryptData = Data(count:cryptLength)

            let status = cryptData.withUnsafeMutableBytes {ivBytes in
                SecRandomCopyBytes(kSecRandomDefault, kCCBlockSizeAES128, ivBytes)
            }

            if (status != 0) {
                throw CrypoError.IVError
            }

            let cryptStatus = cryptData.withUnsafeMutableBytes { cryptBytes in
                data.withUnsafeBytes { dataBytes in
                    keyData.withUnsafeBytes { keyBytes in
                        CCCrypt(CCOperation(kCCEncrypt),
                                CCAlgorithm(kCCAlgorithmAES),
                                options,
                                keyBytes,
                                keyLength,
                                cryptBytes,
                                dataBytes, data.count,
                                cryptBytes+kCCBlockSizeAES128, cryptLength,
                                &numBytesEncrypted)
                    }
                }
            }

            if UInt32(cryptStatus) == UInt32(kCCSuccess) {
                cryptData.count = numBytesEncrypted + ivSize
            }
            else {
                throw CrypoError.AESError
            }

            return cryptData;
        }
    }
}
