//

import Foundation
import SQLite

/// URL extension to store it in Sqlite as String
extension URL: Value {
    /// :nodoc:
    public typealias Datatype = String

    /// :nodoc:
    public static let declaredDatatype = "TEXT"

    /// :nodoc:
    public static func fromDatatypeValue(_ datatypeValue: String) -> URL {
        URL(string: datatypeValue)!
    }

    /// :nodoc:
    public var datatypeValue: String {
        absoluteString
    }
}
