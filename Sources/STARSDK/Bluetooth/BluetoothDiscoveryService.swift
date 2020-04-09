import CoreBluetooth
import Foundation

/// The discovery service responsible of scanning for nearby bluetooth devices offering the STAR service
class BluetoothDiscoveryService: NSObject {

    /// The manager
    private var manager: CBCentralManager?

    /// A delegate for receiving the discovery callbacks
    public weak var delegate: BluetoothDiscoveryDelegate?

    /// A  delegate capable of responding to permission requests
    public weak var permissionDelegate: BluetoothPermissionDelegate?

    /// The storage for last connecting dates of peripherals
    private let storage: PeripheralStorage

    /// A logger for debugging
    public weak var logger: LoggingDelegate?

    /// A list of peripherals pending for retriving info
    private var pendingPeripherals: [CBPeripheral] = []

    /// A list of peripherals that are about to be discarded
    private var peripheralsToDiscard: [CBPeripheral]?

    /// Transmission power levels per discovered peripheral
    private var powerLevelsCache: [UUID: Double] = [:]

    /// The computed distance from the discovered peripherals
    private var RSSICache: [UUID: Double] = [:]

    /// All service ID to scan for
    private var serviceIds: [CBUUID] = [] {
        didSet {
            if oldValue != serviceIds {
                updateServices()
            }
        }
    }

    /// Initialize the discovery object with a storage.
    /// - Parameters:
    ///   - storage: The storage.
    init(storage: PeripheralStorage) {
        self.storage = storage
        super.init()
    }

    /// Sets the list of service IDs to scan for
    /// - Parameter serviceIDs: The list of service IDs
    public func set(serviceIDs: [String]) {
        serviceIds = serviceIDs.map(CBUUID.init(string:))
    }

    /// Update all services
    private func updateServices() {
        guard manager?.state == .some(.poweredOn) else { return }
        if serviceIds != [] {
            manager?.scanForPeripherals(withServices: serviceIds, options: [
                CBCentralManagerOptionShowPowerAlertKey: NSNumber(booleanLiteral: true),
            ])
            DispatchQueue.main.async {
                self.logger?.log(type: .receiver, " scanning for \(self.serviceIds.map { $0.uuidString }.joined(separator: ", "))")
            }
        }
    }

    /// Start the scanning service for nearby devices
    public func startScanning() {
        logger?.log(type: .receiver, " start Scanning")
        if manager != nil {
            manager?.stopScan()
            if serviceIds != [] {
                manager?.scanForPeripherals(withServices: serviceIds, options: [
                    CBCentralManagerOptionShowPowerAlertKey: NSNumber(booleanLiteral: true),
                ])
                logger?.log(type: .receiver, " scanning for \(serviceIds.map { $0.uuidString }.joined(separator: ", "))")
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
        logger?.log(type: .receiver, "stop Scanning")
        logger?.log(type: .receiver, "going to sleep with \(pendingPeripherals) peripherals \n")
        manager?.stopScan()
        manager = nil
        pendingPeripherals.removeAll()
    }
}

// MARK: CBCentralManagerDelegate implementation

extension BluetoothDiscoveryService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger?.log(type: .receiver, state: central.state, prefix: "centralManagerDidUpdateState")
        switch central.state {
        case .poweredOn where !serviceIds.isEmpty:
            logger?.log(type: .receiver, " scanning for \(serviceIds.map { $0.uuidString }.joined(separator: ", "))")
            manager?.scanForPeripherals(withServices: serviceIds, options: [
                CBCentralManagerOptionShowPowerAlertKey: NSNumber(booleanLiteral: true),
            ])
            peripheralsToDiscard?.forEach { peripheral in
                try? self.storage.discard(uuid: peripheral.identifier.uuidString)
                self.manager?.cancelPeripheralConnection(peripheral)
            }
            peripheralsToDiscard = nil
        case .poweredOff:
            permissionDelegate?.deviceTurnedOff()
        case .unauthorized:
            permissionDelegate?.unauthorized()
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        logger?.log(type: .receiver, " didDiscover: \(peripheral), rssi: \(RSSI)db")
        if let power = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? Double {
            logger?.log(type: .receiver, " found TX-Power in Advertisment data: \(power)")
            powerLevelsCache[peripheral.identifier] = power
        } else {
            logger?.log(type: .receiver, " TX-Power not available")
        }
        RSSICache[peripheral.identifier] = Double(truncating: RSSI)

        if let manuData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
        manuData.count == 26 { // TODO: add validation of manufacturer data, not only based on bytecount
            let id = peripheral.identifier
            try? delegate?.didDiscover(data: manuData, TXPowerlevel: powerLevelsCache[id], RSSI: RSSICache[id])
            logger?.log(type: .receiver, " got Manufacturer Data \(manuData.hexEncodedString)")
            #if CALIBRATION
                let identifier = String(data: manuData[0..<4], encoding: .utf8) ?? "Unable to decode"
                logger?.log(type: .receiver, " → ✅ Received (identifier: \(identifier)) (\(manuData.count) bytes) from \(peripheral.identifier) at \(Date()): \(manuData.hexEncodedString)")
            #else
                logger?.log(type: .receiver, " → ✅ Received (\(manuData.count) bytes) from \(peripheral.identifier) at \(Date()): \(manuData.hexEncodedString)")
            #endif
        } else {
            // Only connect if we didn't got manufacturer data
            // we only get the manufacturer if iOS is activly scanning
            // otherwise we have to connect to the peripheral and read the characteristics
            try? storage.setDiscovery(uuid: peripheral.identifier)
            pendingPeripherals.append(peripheral)
            central.connect(peripheral, options: nil)
        }
    }

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger?.log(type: .receiver, " didConnect: \(peripheral)")
        try? storage.setConnection(uuid: peripheral.identifier)
        peripheral.delegate = self
        peripheral.discoverServices(serviceIds)
        peripheral.readRSSI()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let entity = try? storage.get(uuid: peripheral.identifier),
            let lastConnection = entity.lastConnection {
            if Date().timeIntervalSince(lastConnection) > BluetoothConstants.peripheralDisposeInterval {
                logger?.log(type: .receiver, " didDisconnectPeripheral dispose because last connection was \(Date().timeIntervalSince(lastConnection))seconds ago")
                pendingPeripherals.removeAll(where: { $0.identifier == peripheral.identifier })
                try? storage.discard(uuid: peripheral.identifier.uuidString)
                return
            }
        }

        var delay = 0
        if let error = error {
            logger?.log(type: .receiver, " didDisconnectPeripheral (unexpected): \(peripheral) with error: \(error)")
        } else {
            logger?.log(type: .receiver, " didDisconnectPeripheral (successful): \(peripheral)")

            // Do not re-connect to the same (iOS) peripheral right away again to save battery
            delay = BluetoothConstants.peripheralReconnectDelay
        }

        central.connect(peripheral, options: [
            CBConnectPeripheralOptionStartDelayKey: NSNumber(integerLiteral: delay),
        ])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger?.log(type: .receiver, " didFailToConnect: \(peripheral)")
        logger?.log(type: .receiver, " didFailToConnect error: \(error.debugDescription)")

        if let entity = try? storage.get(uuid: peripheral.identifier) {
            if let lastConnection = entity.lastConnection,
                Date().timeIntervalSince(lastConnection) > BluetoothConstants.peripheralDisposeInterval {
                logger?.log(type: .receiver, " didFailToConnect dispose because last connection was \(Date().timeIntervalSince(lastConnection))seconds ago")
                pendingPeripherals.removeAll(where: { $0.identifier == peripheral.identifier })
                try? storage.discard(uuid: peripheral.identifier.uuidString)
                return
            } else if Date().timeIntervalSince(entity.discoverTime) > BluetoothConstants.peripheralDisposeIntervalSinceDiscovery {
                logger?.log(type: .receiver, " didFailToConnect dispose because connection never suceeded and was \(Date().timeIntervalSince(entity.discoverTime))seconds ago")
                pendingPeripherals.removeAll(where: { $0.identifier == peripheral.identifier })
                try? storage.discard(uuid: peripheral.identifier.uuidString)
                return
            }
        }

        central.connect(peripheral, options: nil)
    }

    func centralManager(_: CBCentralManager, willRestoreState dict: [String: Any]) {
        logger?.log(type: .receiver, " CentralManager#willRestoreState")
        if let peripherals: [CBPeripheral] = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            peripheralsToDiscard = []

            try? storage.loopThrough(block: { (entity) -> Bool in
                var toDiscard: String?
                if let lastConnection = entity.lastConnection,
                    Date().timeIntervalSince(lastConnection) > BluetoothConstants.peripheralDisposeInterval {
                    toDiscard = entity.uuid
                } else if Date().timeIntervalSince(entity.discoverTime) > BluetoothConstants.peripheralDisposeIntervalSinceDiscovery {
                    toDiscard = entity.uuid
                }
                if let toDiscard = toDiscard,
                    let peripheralToDiscard = peripherals.first(where: { $0.identifier.uuidString == toDiscard }) {
                    peripheralsToDiscard?.append(peripheralToDiscard)
                }
                return true
            })

            pendingPeripherals.append(contentsOf: peripherals.filter { !(peripheralsToDiscard?.contains($0) ?? false) })
            logger?.log(type: .receiver, "CentralManager#willRestoreState restoring peripherals \(pendingPeripherals) discarded \(peripheralsToDiscard.debugDescription) \n")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error _: Error?) {
        RSSICache[peripheral.identifier] = Double(truncating: RSSI)
    }
}

extension BluetoothDiscoveryService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            logger?.log(type: .receiver, " didDiscoverCharacteristicsFor" + error.localizedDescription)
            return
        }
        let cbuuid = BluetoothConstants.characteristicsCBUUID
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == cbuuid }) else {
            return
        }
        peripheral.readValue(for: characteristic)
        logger?.log(type: .receiver, " found characteristic \(peripheral.name.debugDescription)")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger?.log(type: .receiver, " didUpdateValueFor " + error.localizedDescription)
            manager?.cancelPeripheralConnection(peripheral)
            return
        }

        guard let data = characteristic.value else {
            logger?.log(type: .receiver, " → ❌ Could not read data from characteristic of \(peripheral.identifier) at \(Date())")
            manager?.cancelPeripheralConnection(peripheral)
            return
        }

        guard data.count == 26 else {
            logger?.log(type: .receiver, " → ❌ Received wrong number of bytes (\(data.count) bytes) from \(peripheral.identifier) at \(Date())")
            manager?.cancelPeripheralConnection(peripheral)
            return
        }
        #if CALIBRATION
            let identifier = String(data: data[0..<4], encoding: .utf8) ?? "Unable to decode"
            logger?.log(type: .receiver, " → ✅ Received (identifier: \(identifier)) (\(data.count) bytes) from \(peripheral.identifier) at \(Date()): \(data.hexEncodedString)")
        #else
            logger?.log(type: .receiver, " → ✅ Received (\(data.count) bytes) from \(peripheral.identifier) at \(Date()): \(data.hexEncodedString)")
        #endif
        manager?.cancelPeripheralConnection(peripheral)

        let id = peripheral.identifier
        try? delegate?.didDiscover(data: data, TXPowerlevel: powerLevelsCache[id], RSSI: RSSICache[id])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        logger?.log(type: .receiver, " didDiscoverServices for \(peripheral.identifier)")
        if let error = error {
            logger?.log(type: .receiver, error.localizedDescription)
            return
        }
        if let service = peripheral.services?.first(where: { serviceIds.contains($0.uuid) }) {
            peripheral.discoverCharacteristics([BluetoothConstants.characteristicsCBUUID], for: service)
        } else {
            logger?.log(type: .receiver, " No service found 🤬")
            try? storage.discard(uuid: peripheral.identifier.uuidString)
            manager?.cancelPeripheralConnection(peripheral)
        }
    }
}

extension Data {
    var hexEncodedString: String {
        return map { String(format: "%02hhx ", $0) }.joined()
    }
}
