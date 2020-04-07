import Foundation

/// A delegate used to respond on STAR events
protocol STARMatcherDelegate: class {
    /// We found a match
    func didFindMatch()

    /// A new handshake occured
    func handShakeAdded()
}

/// matcher for STAR tokens
class STARMatcher {
    /// The STAR crypto algorithm
    private let starCrypto: STARCryptoProtocol

    /// Databse
    private weak var database: STARDatabase!

    /// Delegate to notify on STAR events
    public weak var delegate: STARMatcherDelegate!

    /// Initializer
    /// - Parameters:
    ///   - database: databse
    ///   - starCrypto: star algorithm
    init(database: STARDatabase, starCrypto: STARCrypto) throws {
        self.database = database
        self.starCrypto = starCrypto
    }

    /// check for new known case
    /// - Parameter knownCase: known Case
    func checkNewKnownCase(_ knownCase: KnownCaseModel) throws {
        var matchingHandshakeId: Int?

        try database.handshakesStorage.loopThrough(block: { (handshake, handshakeId) -> Bool in
            if self.starCrypto.validate(key: knownCase.key, star: handshake.star) {
                matchingHandshakeId = handshakeId
                return false
            }
            return true
        })

        if let matchingHandshakeId = matchingHandshakeId {
            try database.handshakesStorage.addKnownCase(knownCase.id, to: matchingHandshakeId)
            delegate.didFindMatch()
        }
    }
}

// MARK: BluetoothDiscoveryDelegate implementation

extension STARMatcher: BluetoothDiscoveryDelegate {
    func didDiscover(data: Data, distance: Double?) throws {
        var matchingKnownCaseId = try database.handshakesStorage.starExists(star: data)

        if matchingKnownCaseId == nil {
            try database.knownCasesStorage.loopThrough { (knownCase) -> Bool in
                if self.starCrypto.validate(key: knownCase.key, star: data) {
                    matchingKnownCaseId = knownCase.id
                    return false
                }
                return true
            }
        }

        let handshake = HandshakeModel(timestamp: Date(),
                                       star: data,
                                       distance: distance,
                                       knownCaseId: matchingKnownCaseId)
        try database.handshakesStorage.add(handshake: handshake)

        delegate.handShakeAdded()
        if matchingKnownCaseId != nil {
            delegate.didFindMatch()
        }
    }
}