//

import Foundation

/// SDK Errors
public enum STARTracingErrors: Error {
    /// Networking Error
    case NetworkingError(error: Error?)

    /// Error happend during known case synchronization
    case CaseSynchronizationError

    /// Cryptography Error
    case CryptographyError(error: String)

    /// Databse Error
    case DatabaseError(error: Error)

    /// Bluetooth device turned off
    case BluetoothTurnedOff

    /// Bluetooth permission error
    case PermissonError
}
