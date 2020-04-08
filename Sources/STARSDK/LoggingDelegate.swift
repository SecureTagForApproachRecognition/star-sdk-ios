//

import CoreBluetooth
import Foundation

/// A logging delegate
public protocol LoggingDelegate: class {
    /// Log a string
    /// - Parameter string: The string to log
    func log(_ string: String)
}

extension LoggingDelegate {
    /// Log
    /// - Parameters:
    ///   - state: The state
    ///   - prefix: A prefix
    func log(state: CBManagerState, prefix: String = "") {
        switch state {
        case .poweredOff:
            log("\(prefix): poweredOff")
        case .poweredOn:
            log("\(prefix): poweredOn")
        case .resetting:
            log("\(prefix): resetting")
        case .unauthorized:
            log("\(prefix): unauthorized")
        case .unknown:
            log("\(prefix): unknown")
        case .unsupported:
            log("\(prefix): unsupported")
        @unknown default:
            fatalError()
        }
    }
}
