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


        var cryptor: CCCryptorRef? = nil

        init(keyData:Data) throws {
            self.keyData = keyData

            keyLength = keyData.count

            ivSize = kCCBlockSizeAES128;

            cryptLength = size_t(ivSize + 16 + kCCBlockSizeAES128)
            let status = keyData.withUnsafeBytes { keyBytes in
                CCCryptorCreate(CCOperation(kCCEncrypt),
                                CCAlgorithm(kCCAlgorithmAES),
                                CCOptions(kCCModeCTR),
                                keyBytes,
                                keyLength,
                                nil,
                                &cryptor)
            }
            if (status != 0) {
                throw CrypoError.AESError
            }
        }

        deinit {
            CCCryptorRelease(cryptor)
        }

        func encrypt(data: Data) throws -> Data {

            var cryptData = Data(count:data.count)

            var numBytesEncrypted: size_t = 0
            
            let cryptStatus = cryptData.withUnsafeMutableBytes { cryptBytes in
                data.withUnsafeBytes { dataBytes in
                    CCCryptorUpdate(cryptor,
                                    dataBytes,
                                    data.count,
                                    cryptBytes,
                                    data.count,
                                    &numBytesEncrypted)
                }
            }

            if UInt32(cryptStatus) != UInt32(kCCSuccess) {
                throw CrypoError.AESError
            }

            return cryptData;
        }
    }
}
