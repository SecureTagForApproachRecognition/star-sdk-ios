//

import CommonCrypto
import Foundation

class STARCryptoModule {
    private let store: SecretKeyStorageProtocol

    init?(store: SecretKeyStorageProtocol = SecretKeyStorage.shared) {
        self.store = store
        do {
            let keys = try store.get()
            if keys.isEmpty {
                try generateInitialSecretKey()
            }
        } catch KeychainError.notFound {
            do {
                try generateInitialSecretKey()
            } catch {
                return nil
            }
        } catch KeychainError.cannotAccess {
            return nil
        } catch {
            return nil
        }
    }

    private func getSKt1(SKt0: Data) -> Data {
        return Crypto.sha256(SKt0)
    }

    private func rotateSK() throws {
        var keys = try store.get()
        guard let firstKey = keys.first else {
            throw CrypoError.dataIntegrity
        }
        let nextEpoch = firstKey.epoch.getNext()
        let sKt1 = getSKt1(SKt0: firstKey.keyData)
        keys.insert(SecretKey(epoch: nextEpoch, keyData: sKt1), at: 0)
        while keys.count > CryptoConstants.numberOfDaysToKeepData {
            _ = keys.popLast()
        }
        try store.set(keys)
    }

    public func getCurrentSK(day: Epoch) throws -> Data {
        var keys = try store.get()
        while keys.first!.epoch.isBefore(other: day) {
            try rotateSK()
            keys = try store.get()
        }
        guard let firstKey = keys.first else {
            throw CrypoError.dataIntegrity
        }
        assert(firstKey.epoch.timestamp == day.timestamp)
        return firstKey.keyData
    }

    public func createEphIds(secretKey: Data) throws -> [Data] {
        let hmac = Crypto.hmac(msg: CryptoConstants.broadcastKey, key: secretKey)

        let zeroData = Data(count: CryptoConstants.keyLenght * CryptoConstants.numberOfEpochsPerDay)

        let aes = try Crypto.AESCTREncrypt(keyData: hmac)

        var ephIds = [Data]()
        let prgData = try aes.encrypt(data: zeroData)
        for i in 0 ..< CryptoConstants.numberOfEpochsPerDay {
            let pos = i * CryptoConstants.keyLenght
            ephIds.append(prgData[pos ..< pos + CryptoConstants.keyLenght])
        }

        return ephIds
    }

    public func getCurrentEphId() throws -> Data {
        let currentEpoch = Epoch()
        let currentSk = try getCurrentSK(day: currentEpoch)
        let counter = Int((Date().timeIntervalSince1970 - currentEpoch.timestamp) / Double(CryptoConstants.millisecondsPerEpoch))
        return try createEphIds(secretKey: currentSk)[counter]
    }

    public func checkContacts(secretKey: Data, onsetDate: Epoch, bucketDate: Epoch, getHandshake: (Date) -> ([HandshakeModel])) throws -> HandshakeModel? {
        var dayToTest: Epoch = onsetDate
        var secretKeyForDay: Data = secretKey
        while dayToTest.isBefore(other: bucketDate) {
            let handshakesOnDay = getHandshake(Date(timeIntervalSince1970: dayToTest.timestamp))
            guard !handshakesOnDay.isEmpty else {
                dayToTest = dayToTest.getNext()
                secretKeyForDay = getSKt1(SKt0: secretKeyForDay)
                continue
            }

            // generate all ephIds for day
            let ephIds = try createEphIds(secretKey: secretKeyForDay)
            // check all handshakes if they match any of the ephIds
            for handshake in handshakesOnDay {
                for ephId in ephIds {
                    if handshake.star == ephId {
                        return handshake
                    }
                }
            }

            // update day to next day and rotate sk accordingly
            dayToTest = dayToTest.getNext()
            secretKeyForDay = getSKt1(SKt0: secretKeyForDay)
        }
        return nil
    }

    public func getSecretKeyForPublishing(onsetDate: Date) throws -> Data? {
        let keys = try store.get()
        let epoch = Epoch(date: onsetDate)
        for key in keys {
            if key.epoch == epoch {
                return key.keyData
            }
        }
        if let last = keys.last,
            epoch.isBefore(other: last.epoch) {
            return last.keyData
        }
        return nil
    }

    public func reset() {
        store.removeAllObject()
    }

    private func generateInitialSecretKey() throws {
        let keyData = try generateRandomKey()
        try store.set([SecretKey(epoch: Epoch(), keyData: keyData)])
    }

    private func generateRandomKey() throws -> Data {
        var keyData = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, Int(CC_SHA256_DIGEST_LENGTH), $0.baseAddress!)
        }
        guard result == errSecSuccess else {
            throw KeychainError.cannotAccess
        }
        return keyData
    }
}
