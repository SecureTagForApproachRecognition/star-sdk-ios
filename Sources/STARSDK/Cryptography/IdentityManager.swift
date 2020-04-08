//  Created by Loïc Gardiol on 30.03.20.

import Foundation
import CommonCrypto


/// Responsible for generating the secret keys (SKs) and deriving the Ephemeral IDs (EphID)
/// Currently not thread-safe.
class IdentityManager {
    
    static let shared = IdentityManager()
    
    init() {}

    /// Last nbStoredEpochs SKs, in chronological order. Last is current.
    /// Generated on first access, then persisted securely and rotated.
    /// Guarenteed to be non-empty
    private var SKs: [SK] {
        let persistenceKey = "SKs"
        var sks: [SK] = {
            if let persisted: [SK] = SecurePersistence.shared.object(key: persistenceKey) {
                return persisted
            }
            #warning("TODO If Keychain access fails (device just rebooted for example) and we can't read the previously persisted keys, we are going to override them here.")
            let initialSK = SK(epoch: Epoch.current, keyData: Utils.generateRandomKey(nbBits: GlobalParameters.SKNbBits))
            return [initialSK]
        }()
        let currentEpoch = Epoch.current
        if let last = sks.last, last.epoch != currentEpoch {
            var sk = last
            while sk.epoch < currentEpoch {
                sk = sk.next
                sks.append(sk)
            }
        }
        if sks.count > GlobalParameters.nbStoredEpochs {
            sks = Array(sks.dropFirst(sks.count - Int(GlobalParameters.nbStoredEpochs)))
        }
        SecurePersistence.shared.set(sks, key: persistenceKey)
        return sks
    }
    
    private var currentEphIDCache: EphID?
    
    /// The EphID that corresponds to the current Epoch.
    /// See EpochTracker to know when epochs change.
    var currentEphID: EphID {
        let currentSK = self.SKs.last! // doc says so
        if let cached = self.currentEphIDCache, cached.epoch == currentSK.epoch {
            return cached
        }
        let broadcast = "broadcast".data(using: .utf8)!
        let hmac = Utils.hmacSHA256(msg: broadcast, key: currentSK.keyData)
        let truncated = hmac.dropLast(hmac.count-GlobalParameters.EphIDNbBytes).withUnsafeBytes { Data($0) }
        let ephId = EphID(epoch: currentSK.epoch, data: truncated)
        self.currentEphIDCache = ephId
        return ephId
    }
}

/// Represents a secret key SK along with its corresponding epoch.
struct SK: Codable, CustomStringConvertible {
    let epoch: Epoch
    let keyData: Data
    
    var next: SK {
        let data = Utils.sha256(data: self.keyData)
        return SK(epoch: self.epoch.next, keyData: data)
    }
    
    var description: String {
        return "<SK_\(self.epoch.index): \(self.keyData.hexEncodedString)>"
    }
}

private class Utils {
    /// Generates a random key using CommonCrypto.
    /// Assumes nbBits is a multiple of 8.
    static func generateRandomKey(nbBits: Int) -> Data {
        var bytes = [UInt8](repeating: UInt8(0), count: nbBits / 8)
        let statusCode = CCRandomGenerateBytes(&bytes, bytes.count)
        if statusCode != CCRNGStatus(kCCSuccess) {
            fatalError("Cannot generate key of length \(nbBits) bits")
        }
        return Data(bytes: bytes, count: bytes.count)
    }
    
    static func sha256(data: Data) -> Data {
        var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
    }
    
    /// Perform an HMAC function on a message using a secret key
    /// - Parameters:
    ///   - msg: The message to be hashed
    ///   - key: The key to use for the hash
    static func hmacSHA256(msg: Data, key: Data) -> Data {
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

struct EphID: Codable, CustomStringConvertible {
    /// Timestamp of discovery of self, or timestamp of epoch if own EphID
    let timestamp: TimeInterval
    let epoch: Epoch
    let data: Data
    let advertisementString: String
    
    /// Use this constructor for self-generated EphIDs (the ones that this device advertises)
    init(epoch: Epoch, data: Data) {
        self.timestamp = epoch.timestamp
        self.epoch = epoch
        self.data = data
        self.advertisementString = String(data.base64EncodedString())
    }
    
    /// Use this constructor or init(timestamp:data:) for scanned EphIDs (the ones that this device detects)
    init?(timestamp: TimeInterval, advertisementString: String) {
        guard let epoch = Epoch(timestamp: timestamp), let data = Data(base64Encoded: advertisementString) else {
            return nil
        }
        self.timestamp = timestamp
        self.epoch = epoch
        self.data = data
        self.advertisementString = advertisementString
    }
    
    /// Use this constructor or init(timestamp:advertisementString:) for scanned EphIDs (the ones that this device detects)
    init?(timestamp: TimeInterval, data: Data) {
        guard let epoch = Epoch(timestamp: timestamp) else {
            return nil
        }
        self.timestamp = timestamp
        self.epoch = epoch
        self.data = data
        self.advertisementString = data.base64EncodedString()
    }
    
    var description: String {
        return "<EphID_\(self.epoch.index): \(self.data.hexEncodedString)>"
    }
}

extension Data {
    var hexEncodedString: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
