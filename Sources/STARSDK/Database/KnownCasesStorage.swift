//

import Foundation
import SQLite

/// Storage used to persist STAR known cases
class KnownCasesStorage {
    /// Database connection
    private let database: Connection

    /// Name of the table
    let table = Table("known_cases")

    /// Column definitions
    let idColumn = Expression<Int>("id")
    let dayColumn = Expression<String>("day")
    let keyColumn = Expression<Data>("key")

    /// Initializer
    /// - Parameter database: database connection
    init(database: Connection) throws {
        self.database = database
        try createTable()
    }

    /// Create the table
    private func createTable() throws {
        try database.run(table.create(ifNotExists: true) { t in
            t.column(idColumn, primaryKey: true)
            t.column(dayColumn)
            t.column(keyColumn)
        })
    }

    /// add a known case
    /// - Parameter kc: known case
    func add(knownCase kc: KnownCaseModel) throws {
        let insert = table.insert(
            dayColumn <- kc.day,
            keyColumn <- kc.key
        )
        try database.run(insert)
    }

    /// remove known case
    /// - Parameter kc: known case
    func remove(knownCase kc: KnownCaseModel) throws {
        let removedCase = table.filter(idColumn == kc.id)
        try database.run(removedCase.delete())
    }

    /// add multiple known cases
    /// - Parameter kcs:
    func add(knownCases kcs: [KnownCaseModel]) throws {
        try database.transaction {
            try kcs.forEach { try add(knownCase: $0) }
        }
    }

    /// Current max identifier to speed up parsing
    var maxId: Int {
        return (try? database.scalar(table.select(idColumn.max))) ?? 0
    }

    /// Delete all entries
    func emptyStorage() throws {
        try database.run(table.delete())
    }

    /// helper function to loop through all entries
    /// - Parameter block: execution block should return false to break looping
    func loopThrough(block: (KnownCaseModel) -> Bool) throws {
        for row in try database.prepare(table) {
            let model = KnownCaseModel(id: row[idColumn], action: nil, key: row[keyColumn], day: row[dayColumn])
            if !block(model) {
                break
            }
        }
    }
}
