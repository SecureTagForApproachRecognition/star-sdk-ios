import Foundation

/// A delegate used to respond on STAR events
protocol STARMatcherDelegate: class {
    /// We found a match
    func didFindMatch()

    /// A new handshake occured
    func handShakeAdded(_ handshake: HandshakeModel)
}

/// matcher for STAR tokens
class STARMatcher {
    /// The STAR crypto algorithm
    private let starCrypto: STARCryptoModule

    /// Databse
    private weak var database: STARDatabase!

    /// Delegate to notify on STAR events
    public weak var delegate: STARMatcherDelegate!

    /// Initializer
    /// - Parameters:
    ///   - database: databse
    ///   - starCrypto: star algorithm
    init(database: STARDatabase, starCrypto: STARCryptoModule) throws {
        self.database = database
        self.starCrypto = starCrypto
    }

    /// check for new known case
    /// - Parameter knownCase: known Case
    func checkNewKnownCase(_ knownCase: KnownCaseModel) throws {
        var matchingHandshakeId: Int?

        try database.handshakesStorage.loopThrough(block: { (handshake, handshakeId) -> Bool in
            /*if self.starCrypto.validate(key: knownCase.key, star: handshake.star) {
                matchingHandshakeId = handshakeId
                return false
            }*/
            return true
        })

        if let matchingHandshakeId = matchingHandshakeId, let knownCaseId = knownCase.id {
            try database.handshakesStorage.addKnownCase(knownCaseId, to: matchingHandshakeId)
            delegate.didFindMatch()
        }
    }
}

// MARK: BluetoothDiscoveryDelegate implementation

extension STARMatcher: BluetoothDiscoveryDelegate {
    func didDiscover(data: Data, TXPowerlevel: Double?, RSSI: Double?) throws {
        var matchingKnownCaseId = try database.handshakesStorage.starExists(star: data)

        if matchingKnownCaseId == nil {
            try database.knownCasesStorage.loopThrough { (knownCase) -> Bool in
                /*if self.starCrypto.validate(key: knownCase.key, star: data) {
                    matchingKnownCaseId = knownCase.id
                    return false
                }*/
                return true
            }
        }

        let handshake = HandshakeModel(timestamp: Date(),
                                       star: data,
                                       TXPowerlevel: TXPowerlevel,
                                       RSSI: RSSI,
                                       knownCaseId: matchingKnownCaseId)
        try database.handshakesStorage.add(handshake: handshake)

        delegate.handShakeAdded(handshake)
        if matchingKnownCaseId != nil {
            delegate.didFindMatch()
        }
    }
}
