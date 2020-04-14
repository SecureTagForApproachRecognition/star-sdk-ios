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
    func checkNewKnownCase(_ knownCase: KnownCaseModel, bucketDay: String) throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let onset = dateFormatter.date(from: knownCase.onset)!
        let bucketDayDate = dateFormatter.date(from: bucketDay)!

        let handshake = try starCrypto.checkContacts(secretKey: knownCase.key, onsetDate: Epoch(date: onset), bucketDate: Epoch(date: bucketDayDate)) { (day) -> ([HandshakeModel]) in
            (try? database.handshakesStorage.getBy(day: day)) ?? []
        }

        if let handshakeid = handshake?.identifier, let knownCaseId = knownCase.id {
            try database.handshakesStorage.addKnownCase(knownCaseId, to: handshakeid)
            delegate.didFindMatch()
        }
    }
}

// MARK: BluetoothDiscoveryDelegate implementation

extension STARMatcher: BluetoothDiscoveryDelegate {
    func didDiscover(data : Data, TXPowerlevel : Double?, RSSI : Double?) throws {
        // Do no realtime matching
        let handshake = HandshakeModel(timestamp: Date(),
                                       star: data,
                                       TXPowerlevel: TXPowerlevel,
                                       RSSI: RSSI,
                                       knownCaseId: nil)
        try database.handshakesStorage.add(handshake: handshake)

        delegate.handShakeAdded(handshake)
    }
}
