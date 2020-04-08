//

import CoreBluetooth
import Foundation
import UIKit

/// A service to broadcast bluetooth packets containing the STAR token
class BluetoothBroadcastService: NSObject {
    /// The peripheral manager
    private var peripheralManager: CBPeripheralManager?
    /// The broadcasted service
    private var service: CBMutableService?

    /// The STAR crypto algorithm
    private weak var starCrypto: STARCryptoProtocol?

    /// Random device name for enhanced privacy
    private var localName: String = UUID().uuidString

    /// An object that can handle bluetooth permission requests and errors
    public weak var permissionDelegate: BluetoothPermissionDelegate?

    /// A logger to output messages
    public weak var logger: LoggingDelegate?

    /// The service ID for the current application
    private var serviceId: CBUUID? {
        didSet {
            guard oldValue != serviceId else { return }
            if service == nil {
                addService()
            } else {
                stopService()
                startService()
            }
        }
    }

    /// Create a Bluetooth broadcaster with a STAR crypto algorithm
    /// - Parameter starCrypto: The STAR crypto algorithm
    public init(starCrypto: STARCryptoProtocol) {
        self.starCrypto = starCrypto
        super.init()
    }

    /// Set the service ID
    /// - Parameter serviceId: The new service ID
    public func set(serviceId: String) {
        self.serviceId = CBUUID(string: serviceId)
    }

    /// Start the broadcast service
    public func startService() {
        guard peripheralManager == nil else {
            logger?.log("[Sender]: startService service already started")
            return
        }
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: [
            CBPeripheralManagerOptionShowPowerAlertKey: NSNumber(booleanLiteral: true),
            CBPeripheralManagerOptionRestoreIdentifierKey: "STARTracingPeripheralManagerIdentifier",
        ])
    }

    /// Stops the broadcast service
    public func stopService() {
        logger?.log("[Sender]: stopping Services")

        peripheralManager?.removeAllServices()
        peripheralManager?.stopAdvertising()
        service = nil
        peripheralManager = nil
    }

    /// Adds a bluetooth service and broadcast it
    private func addService() {
        guard peripheralManager?.state == .some(.poweredOn),
            let serviceId = self.serviceId else {
            return
        }
        service = CBMutableService(type: serviceId,
                                   primary: true)
        let characteristic = CBMutableCharacteristic(type: BluetoothConstants.characteristicsCBUUID,
                                                     properties: [.read, .notify],
                                                     value: nil,
                                                     permissions: .readable)
        service?.characteristics = [characteristic]
        peripheralManager?.add(service!)

        logger?.log("[Sender]: added Service with \(serviceId.uuidString)")
    }
}

// MARK: CBPeripheralManagerDelegate implementation

extension BluetoothBroadcastService: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        logger?.log(state: peripheral.state, prefix: "[Sender]: peripheralManagerDidUpdateState")

        switch peripheral.state {
        case .poweredOn where service == nil:
            addService()
        case .poweredOff:
            permissionDelegate?.deviceTurnedOff()
        case .unauthorized:
            permissionDelegate?.unauthorized()
        default:
            break
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error _: Error?) {
        logger?.log(state: peripheral.state, prefix: "[Sender]: peripheralManagerdidAddservice")

        peripheralManager?.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [service.uuid],
            CBAdvertisementDataLocalNameKey: "",
        ])
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        logger?.log(state: peripheral.state, prefix: "peripheralManagerDidStartAdvertising")
        if let error = error {
            logger?.log("[Sender]: peripheralManagerDidStartAdvertising error: \(error.localizedDescription)")
        }
    }

    func peripheralManager(_: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        do {
            let data = try starCrypto!.newTOTP()
            request.value = data
            peripheralManager?.respond(to: request, withResult: .success)
            logger?.log("[Sender]: ← ✅ didReceiveRead: Responded with new token")
        } catch {
            peripheralManager?.respond(to: request, withResult: .unlikelyError)
            logger?.log("[Sender]: ← ❌ didReceiveRead: Could not respond because token was not generated \(error)")
        }
    }

    func peripheralManager(_: CBPeripheralManager, willRestoreState dict: [String: Any]) {
        if let services: [CBMutableService] = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService],
            let service = services.first(where: { $0.uuid == serviceId }) {
            self.service = service
            logger?.log("[Sender]: PeripheralManager#willRestoreState services :\(services.count)")
        }
    }
}
