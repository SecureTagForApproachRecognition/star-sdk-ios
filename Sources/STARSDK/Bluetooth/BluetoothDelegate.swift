//

import Foundation

/// A delegate to respond to bluetooth discovery callbacks
protocol BluetoothDiscoveryDelegate: class {
    /// The discovery service did discover some data and calculated the distance of the source
    /// - Parameters:
    ///   - data: The data received
    ///   - distance: The distance to the emitter
    func didDiscover(data: Data, distance: Double?) throws
}

/// A delegate that can react to bluetooth permission requests
protocol BluetoothPermissionDelegate: class {
    /// The Bluetooth device is turned off
    func deviceTurnedOff()
    /// The app is not authorized to use bluetooth
    func unauthorized()
}
