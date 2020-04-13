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

    func testGenerateEphIds() {
        let store = KeyStore()
        let star: STARCryptoModule = STARCryptoModule(store: store)!
        let allEphsOfToday = try! star.createEphIds(secretKey: star.getSecretKeyForPublishing(onsetDate: Date())!)
        let currentEphId = try! star.getCurrentEphId()
        var matchingCount = 0
        for ephId in allEphsOfToday {
            if ephId == currentEphId {
                matchingCount += 1
            }
        }
        XCTAssert(matchingCount == 1)
    }

    static var allTests = [
        ("sha256", testSha256),
        ("generateEphIds", testGenerateEphIds)
    ]
}
