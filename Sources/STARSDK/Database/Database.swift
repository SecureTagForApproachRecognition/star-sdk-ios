//

import Foundation
import SQLite

/// Wrapper class for all Databases
class STARDatabase {
    /// Database connection
    private let connection: Connection

    /// flag used to set Database as destroyed
    private(set) var isDestroyed = false

    public weak var logger: LoggingDelegate?

    /// application Storage
    private let _applicationStorage: ApplicationStorage
    var applicationStorage: ApplicationStorage {
        guard !isDestroyed else { fatalError("Database is destroyed") }
        return _applicationStorage
    }

    /// handshaked Storage
    private let _handshakesStorage: HandshakesStorage
    var handshakesStorage: HandshakesStorage {
        guard !isDestroyed else { fatalError("Database is destroyed") }
        return _handshakesStorage
    }

    /// knowncase Storage
    private let _knownCasesStorage: KnownCasesStorage
    var knownCasesStorage: KnownCasesStorage {
        guard !isDestroyed else { fatalError("Database is destroyed") }
        return _knownCasesStorage
    }

    /// peripheral Storage
    private let _peripheralStorage: PeripheralStorage
    var peripheralStorage: PeripheralStorage {
        guard !isDestroyed else { fatalError("Database is destroyed") }
        return _peripheralStorage
    }

    /// logging Storage
    private let _logggingStorage: LoggingStorage
    var loggingStorage: LoggingStorage {
        guard !isDestroyed else { fatalError("Database is destroyed") }
        return _logggingStorage
    }

    /// Initializer
    init() throws {
        let fileName = STARDatabase.getDatabasePath()
        connection = try Connection(fileName, readonly: false)
        _knownCasesStorage = try KnownCasesStorage(database: connection)
        _handshakesStorage = try HandshakesStorage(database: connection, knownCasesStorage: _knownCasesStorage)
        _peripheralStorage = try PeripheralStorage(database: connection)
        _applicationStorage = try ApplicationStorage(database: connection)
        _logggingStorage = try LoggingStorage(database: connection)
    }

    /// Discard all data
    func emptyStorage() throws {
        guard !isDestroyed else { fatalError("Database is destroyed") }
        try connection.transaction {
            try handshakesStorage.emptyStorage()
            try knownCasesStorage.emptyStorage()
            try peripheralStorage.emptyStorage()
            try loggingStorage.emptyStorage()
        }
    }

    /// delete Database
    func destroyDatabase() throws {
        let path = STARDatabase.getDatabasePath()
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(atPath: path)
        }
        isDestroyed = true
    }

    /// get database path
    private static func getDatabasePath() -> String {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.appendingPathComponent("STAR_tracing_db").appendingPathExtension("sqlite").absoluteString
    }
}

extension STARDatabase: CustomDebugStringConvertible {
    var debugDescription: String {
        return "DB at path <\(STARDatabase.getDatabasePath())>"
    }
}
