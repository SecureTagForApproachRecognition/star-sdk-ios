import CoreBluetooth
import Foundation
import UIKit.UIApplication

struct PeripheralMetaData {
    var lastConnection: Date?
    var discovery: Date
    var rssi: Double?
    var txPowerlevel: Double?
}

/// The discovery service responsible of scanning for nearby bluetooth devices offering the STAR service
class BluetoothDiscoveryService: NSObject {

    /// The manager
    private var manager: CBCentralManager?

    /// A delegate for receiving the discovery callbacks
    public weak var delegate: BluetoothDiscoveryDelegate?

    /// A  delegate capable of responding to permission requests
    public weak var permissionDelegate: BluetoothPermissionDelegate?

    /// A logger for debugging
    #if CALIBRATION
    public weak var logger: LoggingDelegate?
    #endif

    /// A list of peripherals pending for retriving info
    private var pendingPeripherals: [CBPeripheral : PeripheralMetaData] = [:] {
        didSet {
            if pendingPeripherals.isEmpty {
                endBackgroundTask()
            } else {
                beginBackgroundTask()
            }
            #if CALIBRATION
            logger?.log(type: .receiver, "updatedPeripherals: \n\(pendingPeripherals.keys.map(\.debugDescription).joined(separator: "\n"))")
            #endif
        }
    }

    /// A list of peripherals that are about to be discarded
    private var peripheralsToDiscard: [CBPeripheral]?

    /// Identifier of the background task
    private var backgroundTask: UIBackgroundTaskIdentifier?

    /// All service ID to scan for
    private var serviceIds: [CBUUID] = [] {
        didSet {
            if oldValue != serviceIds {
                updateServices()
            }
        }
    }

    /// Sets the list of service IDs to scan for
    /// - Parameter serviceIDs: The list of service IDs
    public func set(serviceIDs: [String]) {
        serviceIds = serviceIDs.map(CBUUID.init(string:))
    }

    /// Starts a background task
    private func beginBackgroundTask() {
        guard self.backgroundTask == nil else { return }
        #if CALIBRATION
        logger?.log(type: .receiver, "Starting Background Task")
        #endif
        self.backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "ch.ubique.bluetooth.backgroundtask") {
            self.endBackgroundTask()
            #if CALIBRATION
            self.logger?.log(type: .receiver, "Background Task ended")
            #endif
        }
    }

    /// Terminates a Backgroundtask if one is running
    private func endBackgroundTask(){
        guard let identifier = self.backgroundTask else { return }
        #if CALIBRATION
        logger?.log(type: .receiver, "Terminating background Task")
        #endif
        UIApplication.shared.endBackgroundTask(identifier)
        self.backgroundTask = nil
    }

    /// Update all services
    private func updateServices() {
        guard manager?.state == .some(.poweredOn) else { return }
        if !serviceIds.isEmpty {
            manager?.scanForPeripherals(withServices: serviceIds, options: [
                CBCentralManagerOptionShowPowerAlertKey: NSNumber(booleanLiteral: true),
            ])
            #if CALIBRATION
            DispatchQueue.main.async {
                self.logger?.log(type: .receiver, "scanning for \(self.serviceIds.map { $0.uuidString }.joined(separator: ", "))")
            }
            #endif
        }
    }

    private func disposeOldPeripherals(){
        var toDispose: [CBPeripheral] = []
        for (peripheral, metadata) in self.pendingPeripherals where metadata.lastConnection != nil {
            if Date().timeIntervalSince(metadata.lastConnection!) > BluetoothConstants.peripheralDisposeInterval {
                toDispose.append(peripheral)
                #if CALIBRATION
                var state: String
                switch peripheral.state {
                case .connected: state = "connected"
                case .connecting: state = "connecting"
                case .disconnected: state = "disconnected"
                case .disconnecting: state = "disconnecting"
                @unknown default:
                    state = "unknown"
                }
                logger?.log(type: .receiver, "disposeOldPeripherals dispose because last connection was \(Date().timeIntervalSince(metadata.lastConnection!))seconds ago ( state: \(state) ")
                #endif
            }
        }
        for peripheral in toDispose {
            pendingPeripherals[peripheral] = nil
            manager?.cancelPeripheralConnection(peripheral)
        }
    }

    /// Start the scanning service for nearby devices
    public func startScanning() {
        #if CALIBRATION
        logger?.log(type: .receiver, "start Scanning")
        #endif
        if manager != nil {
            manager?.stopScan()
            if serviceIds != [] {
                manager?.scanForPeripherals(withServices: serviceIds, options: [
                    CBCentralManagerOptionShowPowerAlertKey: NSNumber(booleanLiteral: true),
                ])
                #if CALIBRATION
                logger?.log(type: .receiver, "scanning for \(serviceIds.map { $0.uuidString }.joined(separator: ", "))")
                #endif
            }
        } else {
            manager = CBCentralManager(delegate: self, queue: nil, options: [
                CBCentralManagerOptionShowPowerAlertKey: NSNumber(booleanLiteral: true),
                CBCentralManagerOptionRestoreIdentifierKey: "STARTracingCentralManagerIdentifier",
            ])
        }
    }

    /// Stop scanning for nearby devices
    public func stopScanning() {
        #if CALIBRATION
        logger?.log(type: .receiver, "stop Scanning")
        logger?.log(type: .receiver, "going to sleep with \(pendingPeripherals) peripherals \n")
        #endif
        manager?.stopScan()
        manager = nil
        pendingPeripherals.removeAll()
        endBackgroundTask()
    }
}

// MARK: CBCentralManagerDelegate implementation

extension BluetoothDiscoveryService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        #if CALIBRATION
        logger?.log(type: .receiver, state: central.state, prefix: "centralManagerDidUpdateState")
        #endif
        switch central.state {
        case .poweredOn where !serviceIds.isEmpty:
            #if CALIBRATION
            logger?.log(type: .receiver, "scanning for \(serviceIds.map { $0.uuidString }.joined(separator: ", "))")
            #endif
            manager?.scanForPeripherals(withServices: serviceIds, options: [
                CBCentralManagerOptionShowPowerAlertKey: NSNumber(booleanLiteral: true),
            ])
            peripheralsToDiscard?.forEach { peripheral in
                self.manager?.cancelPeripheralConnection(peripheral)
            }
            peripheralsToDiscard = nil
            pendingPeripherals.keys.forEach(handleRestoredPeripheral(_:))
        case .poweredOff:
            permissionDelegate?.deviceTurnedOff()
        case .unauthorized:
            permissionDelegate?.unauthorized()
        default:
            break
        }
    }

    func handleRestoredPeripheral(_ peripheral: CBPeripheral) {

        guard peripheral.state == .connected else {
            #if CALIBRATION
            logger?.log(type: .receiver, "handleRestoredPeripheral \(peripheral) not connected -> reconnecting")
            #endif
            reconnect(peripheral)
            return
        }
        guard peripheral.services != nil else {
            peripheral.discoverServices(serviceIds)
            #if CALIBRATION
            logger?.log(type: .receiver, "handleRestoredPeripheral \(peripheral) no services -> discoverServices")
            #endif
            return
        }

        guard let service = peripheral.services?.first(where: { serviceIds.contains($0.uuid) }) else {
            manager?.cancelPeripheralConnection(peripheral)
            #if CALIBRATION
            logger?.log(type: .receiver, "handleRestoredPeripheral \(peripheral) cancelConnection -> no matching service")
            #endif
            return
        }

        guard service.characteristics != nil else {
            peripheral.discoverCharacteristics([BluetoothConstants.characteristicsCBUUID], for: service)
            #if CALIBRATION
            logger?.log(type: .receiver, "handleRestoredPeripheral \(peripheral) discoverCharacteristics -> no characteristics")
            #endif
            return
        }

        guard let characteristic = service.characteristics?.first(where: { $0.uuid == BluetoothConstants.characteristicsCBUUID}) else {
            manager?.cancelPeripheralConnection(peripheral)
            #if CALIBRATION
            logger?.log(type: .receiver, "handleRestoredPeripheral \(peripheral) cancelPeripheralConnection -> no matching characteristics")
            #endif
            return
        }

        peripheral.readValue(for: characteristic)
        #if CALIBRATION
        logger?.log(type: .receiver, "handleRestoredPeripheral \(peripheral) readValue")
        #endif
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Default.shared.lastDiscovery = Date()
        disposeOldPeripherals()

        #if CALIBRATION
        logger?.log(type: .receiver, "didDiscover: \(peripheral), rssi: \(RSSI)db")
        #endif

        if !pendingPeripherals.keys.contains(peripheral) {
            pendingPeripherals[peripheral] = PeripheralMetaData(lastConnection: nil,
                                                                discovery: Date())
        }

        pendingPeripherals[peripheral]?.discovery = Date()
        pendingPeripherals[peripheral]?.rssi = RSSI.doubleValue
        pendingPeripherals[peripheral]?.txPowerlevel = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? Double

        // Android transmits the token directly in the SCANRSP
        if let manuData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
           manuData.count == 28,
           manuData[0..<2].withUnsafeBytes({ $0.load(as: UInt16.self) }) == BluetoothConstants.androidManufacturerId {

            // drop manufacturer identifier
            let data = manuData.dropFirst(2)

            try? delegate?.didDiscover(data: data, TXPowerlevel: pendingPeripherals[peripheral]?.txPowerlevel, RSSI: pendingPeripherals[peripheral]?.rssi)

            #if CALIBRATION
                logger?.log(type: .receiver, "got Manufacturer Data \(data.hexEncodedString)")
            let identifier = String(data: data[..<4], encoding: .utf8) ?? "Unable to decode"
                logger?.log(type: .receiver, "→ ✅ Received (identifier over ScanRSP: \(identifier)) (\(data.count) bytes) from \(peripheral.identifier) at \(Date()): \(data.hexEncodedString)")
            #endif

            //Cancel connection if it was already made
            manager?.cancelPeripheralConnection(peripheral)
            reconnect(peripheral, delayed: true)
        } else {
            // Only connect if we didn't got manufacturer data
            // we only get the manufacturer if iOS is activly scanning
            // otherwise we have to connect to the peripheral and read the characteristics
            central.connect(peripheral, options: nil)
        }
    }

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        #if CALIBRATION
        logger?.log(type: .receiver, "didConnect: \(peripheral)")
        #endif
        pendingPeripherals[peripheral]?.lastConnection = Date()
        peripheral.delegate = self
        peripheral.discoverServices(serviceIds)
        peripheral.readRSSI()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let entity = pendingPeripherals[peripheral],
            let lastConnection = entity.lastConnection {
            if Date().timeIntervalSince(lastConnection) > BluetoothConstants.peripheralDisposeInterval {
                #if CALIBRATION
                logger?.log(type: .receiver, "didDisconnectPeripheral dispose because last connection was \(Date().timeIntervalSince(lastConnection))seconds ago")
                #endif
                pendingPeripherals[peripheral] = nil
                return
            }
        }

        if let error = error {
            #if CALIBRATION
            logger?.log(type: .receiver, "didDisconnectPeripheral (unexpected): \(peripheral) with error: \(error)")
            #endif
            reconnect(peripheral)
        } else {
            #if CALIBRATION
            logger?.log(type: .receiver, "didDisconnectPeripheral (successful): \(peripheral)")
            #endif
            // Do not re-connect to the same (iOS) peripheral right away again to save battery
            reconnect(peripheral, delayed: true)
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        #if CALIBRATION
        logger?.log(type: .receiver, "didFailToConnect: \(peripheral)")
        logger?.log(type: .receiver, "didFailToConnect error: \(error.debugDescription)")
        #endif

        if let entity = pendingPeripherals[peripheral] {
            if let lastConnection = entity.lastConnection,
                Date().timeIntervalSince(lastConnection) > BluetoothConstants.peripheralDisposeInterval {
                #if CALIBRATION
                logger?.log(type: .receiver, "didFailToConnect dispose because last connection was \(Date().timeIntervalSince(lastConnection))seconds ago")
                #endif
                pendingPeripherals[peripheral] = nil
                return
            } else if Date().timeIntervalSince(entity.discovery) > BluetoothConstants.peripheralDisposeIntervalSinceDiscovery {
                #if CALIBRATION
                logger?.log(type: .receiver, "didFailToConnect dispose because connection never suceeded and was \(Date().timeIntervalSince(entity.discovery))seconds ago")
                #endif
                pendingPeripherals[peripheral] = nil
                return
            }
        }

        reconnect(peripheral)
    }

    func reconnect(_ peripheral: CBPeripheral, delayed: Bool = false) {
           #if CALIBRATION
           logger?.log(type: .receiver, "reconnect to peripheral \(peripheral) \(delayed ?  "delayed" : "right away")")
           #endif
           var options: [String : Any]? = nil
           if delayed {
               options = [CBConnectPeripheralOptionStartDelayKey: NSNumber(integerLiteral: BluetoothConstants.peripheralReconnectDelay)]
           }
           manager?.connect(peripheral, options: options)
       }

    func centralManager(_: CBCentralManager, willRestoreState dict: [String: Any]) {
        #if CALIBRATION
        logger?.log(type: .receiver, "CentralManager#willRestoreState")
        #endif
        if let peripherals: [CBPeripheral] = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            if let lastDiscovery = Default.shared.lastDiscovery,
            Date().timeIntervalSince(lastDiscovery) > BluetoothConstants.peripheralDisposeIntervalSinceDiscovery{
                peripheralsToDiscard = peripherals
                #if CALIBRATION
                let numConnecting = peripherals.filter { $0.state == .connecting }.count
                let numConnected = peripherals.filter { $0.state == .connected }.count
                let numDisconnected = peripherals.filter { $0.state == .disconnected }.count
                logger?.log(type: .receiver, "CentralManager#willRestoreState not restoring Peripherals since they are to old ( connecting -> \(numConnecting), connected -> \(numConnected), disconnected -> \(numDisconnected) )")
                #endif
            } else {
                for peripheral in peripherals {
                    peripheral.delegate = self
                    pendingPeripherals[peripheral] = PeripheralMetaData(lastConnection: nil, discovery: Date())
                }
                #if CALIBRATION
                logger?.log(type: .receiver, "CentralManager#willRestoreState restoring peripherals \(pendingPeripherals)")
                #endif
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error _: Error?) {
        pendingPeripherals[peripheral]?.rssi = Double(truncating: RSSI)
    }
}

extension BluetoothDiscoveryService: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        #if CALIBRATION
        logger?.log(type: .receiver, "didDiscoverServices for \(peripheral.identifier)")
        #endif
        if let error = error {
            #if CALIBRATION
            logger?.log(type: .receiver, "didDiscoverServices \(peripheral) error:" + error.localizedDescription)
            #endif
            reconnect(peripheral)
            return
        }
        if let service = peripheral.services?.first(where: { serviceIds.contains($0.uuid) }) {
            peripheral.discoverCharacteristics([BluetoothConstants.characteristicsCBUUID], for: service)
        } else {
            #if CALIBRATION
            logger?.log(type: .receiver, "No service found 🤬")
            #endif
            manager?.cancelPeripheralConnection(peripheral)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            #if CALIBRATION
            logger?.log(type: .receiver, "didDiscoverCharacteristicsFor \(peripheral) error:" + error.localizedDescription)
            #endif
            reconnect(peripheral)
            return
        }
        let cbuuid = BluetoothConstants.characteristicsCBUUID
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == cbuuid }) else {
            return
        }
        peripheral.readValue(for: characteristic)
        #if CALIBRATION
        logger?.log(type: .receiver, "found characteristic \(peripheral.name.debugDescription)")
        #endif
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            #if CALIBRATION
            logger?.log(type: .receiver, "didUpdateValueFor \(peripheral) error:" + error.localizedDescription)
            #endif
            manager?.cancelPeripheralConnection(peripheral)
            return
        }

        guard let data = characteristic.value else {
            #if CALIBRATION
            logger?.log(type: .receiver, "→ ❌ Could not read data from characteristic of \(peripheral.identifier) at \(Date())")
            #endif
            manager?.cancelPeripheralConnection(peripheral)
            return
        }

        guard data.count == 26 else {
            #if CALIBRATION
            logger?.log(type: .receiver, "→ ❌ Received wrong number of bytes (\(data.count) bytes) from \(peripheral.identifier) at \(Date())")
            #endif
            manager?.cancelPeripheralConnection(peripheral)
            return
        }
        #if CALIBRATION
            let identifier = String(data: data[0..<4], encoding: .utf8) ?? "Unable to decode"
            logger?.log(type: .receiver, "→ ✅ Received (identifier: \(identifier)) (\(data.count) bytes) from \(peripheral.identifier) at \(Date()): \(data.hexEncodedString)")
        #endif
        try? delegate?.didDiscover(data: data, TXPowerlevel: pendingPeripherals[peripheral]?.txPowerlevel, RSSI: pendingPeripherals[peripheral]?.rssi)
        manager?.cancelPeripheralConnection(peripheral)
    }
}

#if CALIBRATION
extension Data {
    var hexEncodedString: String {
        return map { String(format: "%02hhx ", $0) }.joined()
    }
}
#endif
