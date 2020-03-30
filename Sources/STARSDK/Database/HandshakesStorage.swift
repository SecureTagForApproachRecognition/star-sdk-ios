//

import Foundation
import SQLite

/// Storage used to persist STAR handshakes
class HandshakesStorage {
    /// Database connection
    private let database: Connection

    /// Name of the table
    let table = Table("handshakes")

    /// Column definitions
    let idColumn = Expression<Int>("id")
    let timestampColumn = Expression<Date>("timestamp")
    let starColumn = Expression<Data>("star")
    let distanceColumn = Expression<Double?>("distance")
    let associatedKnownCaseColumn = Expression<Int?>("associated_known_case")

    /// Initializer
    /// - Parameters:
    ///   - database: database Connection
    ///   - knownCasesStorage: knownCases Storage
    init(database: Connection, knownCasesStorage: KnownCasesStorage) throws {
        self.database = database
        try createTable(knownCasesStorage: knownCasesStorage)
    }

    /// Create the table
    private func createTable(knownCasesStorage: KnownCasesStorage) throws {
        try database.run(table.create(ifNotExists: true) { t in
            t.column(idColumn, primaryKey: .autoincrement)
            t.column(timestampColumn)
            t.column(starColumn)
            t.column(associatedKnownCaseColumn)
            t.column(distanceColumn)
            t.foreignKey(associatedKnownCaseColumn, references: knownCasesStorage.table, knownCasesStorage.idColumn, delete: .setNull)
        })
    }

    /// returns the known Case Id for a star
    func starExists(star: Data) throws -> Int? {
        let query = table.filter(starColumn == star)
        let row = try database.pluck(query)
        return row?[associatedKnownCaseColumn]
    }

    /// count of entries
    func count() throws -> Int {
        try database.scalar(table.count)
    }

    /// add a Handshake
    /// - Parameter h: handshake
    func add(handshake h: HandshakeModel) throws {
        let insert = table.insert(
            timestampColumn <- h.timestamp,
            starColumn <- h.star,
            associatedKnownCaseColumn <- h.knownCaseId,
            distanceColumn <- h.distance
        )
        try database.run(insert)
    }

    /// Add a known case to the handshake
    /// - Parameters:
    ///   - knownCaseId: identifier of known case
    ///   - handshakeId: identifier of handshake
    func addKnownCase(_ knownCaseId: Int, to handshakeId: Int) throws {
        let handshakeRow = table.filter(idColumn == handshakeId)
        try database.run(handshakeRow.update(associatedKnownCaseColumn <- knownCaseId))
    }

    /// helper function to loop through all entries
    /// - Parameter since: timeinterval used for looping
    /// - Parameter block: execution block should return false to break looping
    func loopThrough(since: Date = Date().addingTimeInterval(-60 * 60 * 24 * 14), block: (HandshakeModel, Int) -> Bool) throws {
        let query = table.filter(timestampColumn > since)
        for row in try database.prepare(query) {
            guard row[associatedKnownCaseColumn] == nil else { continue }
            let model = HandshakeModel(timestamp: row[timestampColumn],
                                       star: row[starColumn],
                                       distance: row[distanceColumn],
                                       knownCaseId: nil)
            if !block(model, row[idColumn]) {
                break
            }
        }
    }

    /// Delete all entries
    func emptyStorage() throws {
        try database.run(table.delete())
    }
}
