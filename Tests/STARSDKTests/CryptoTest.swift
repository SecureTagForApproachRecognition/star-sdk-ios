@testable import STARSDK
import XCTest

fileprivate class KeyStore: SecretKeyStorageProtocol {
    var keys: [SecretKey] = []

    func get() throws -> [SecretKey] {
        return keys
    }
    func set(_ object: [SecretKey]) throws {
        self.keys = object
    }
    func removeAllObject() {
    }
}

final class STARTracingCryptoTests: XCTestCase {
    func testSha256() {
        let string = "COVID19"
        let strData = string.data(using: .utf8)!
        let digest = Crypto.sha256(strData)
        let hex = digest.base64EncodedString()
        XCTAssertEqual(hex, "wdvvalTpy3jExBEyO6iIHps+HUsrnwgCtMGpi86eq4c=")
    }

    func testHmac() {
        let secretKey = "pcu8RDQQhvzL7oCOZjLCBdAodQfNK406m1x9JXugxoY="
        let secretKeyData = Data(base64Encoded: secretKey)!
        let expected = "M+AgJ345G+6AZYu1Cx2IGD6VL1YigLmFrG0roTmIlQA="
        let real = Crypto.hmac(msg: CryptoConstants.broadcastKey, key: secretKeyData)
        XCTAssertEqual(real.base64EncodedString(), expected)
    }

    func testGenerateEphIds() {
        let store = KeyStore()
        let star: STARCryptoModule = STARCryptoModule(store: store)!
        let allEphsOfToday = try! star.createEphIds(secretKey: star.getSecretKeyForPublishing(onsetDate: Date())!)
        let currentEphId = try! star.getCurrentEphId()
        var matchingCount = 0
        for ephId in allEphsOfToday {
            XCTAssert(ephId.count == CryptoConstants.keyLenght)
            if ephId == currentEphId {
                matchingCount += 1
            }
        }
        XCTAssert(matchingCount == 1)
    }

    func testGenerationEphsIdsWithAndorid(){
        let store = KeyStore()
        let star: STARCryptoModule = STARCryptoModule(store: store)!
        let base64SecretKey = "MZbZmgsA+9b0A8mkkcAQJcww727M8tlI1zO/2eGZ/DA="
        let base64EncodedEphId = "IYiXz8YZcqTUGNhmHk422UlogB6bQAFGr6Q="
        let base64EncodedEph1Id = "iavGGZym0MwjmWhJP8vk4Fmer2sO/YHGgmg="
        let allEphId: [Data] = try! star.createEphIds(secretKey: Data(base64Encoded: base64SecretKey)!)
        var matchingCount = 0
        for ephId in allEphId {
            if ephId.base64EncodedString() == base64EncodedEphId {
                matchingCount += 1
            }
            if ephId.base64EncodedString() == base64EncodedEph1Id {
                matchingCount += 1
            }
        }
        XCTAssert(matchingCount == 2)
    }

    static var allTests = [
        ("sha256", testSha256),
        ("generateEphIds", testGenerateEphIds),
        ("generateEphIdsAndroid", testGenerationEphsIdsWithAndorid),
        ("testHmac", testHmac)
    ]
}
