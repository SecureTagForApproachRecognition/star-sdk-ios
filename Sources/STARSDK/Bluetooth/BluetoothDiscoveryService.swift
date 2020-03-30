import CoreBluetooth
import Foundation

/// The discovery service responsible of scanning for nearby bluetooth devices offering the STAR service
class BluetoothDiscoveryService: NSObject {
    // iOS sends at 12bm? Android seems to vary between -1dbm (HIGH_POWER) and -21dbm (LOW_POWER)
    private var defaultPower = 12.0

    /// The manager
    private var manager: CBCentralManager?

    /// A delegate for receiving the discovery callbacks
    public weak var delegate: BluetoothDiscoveryDelegate?

    /// A  delegate capable of responding to permission requests
    public weak var permissionDelegate: BluetoothPermissionDelegate?

    /// The storage for last connecting dates of peripherals
    private let storage: PeripheralStorage

    #if DEBUG
        /// A logger for debugging
        public weak var logger: LoggingDelegate?
    #endif

    /// A list of peripherals pending for retriving info
    private var pendingPeripherals: [CBPeripheral] = []

    /// A list of peripherals that are about to be discarded
    private var peripheralsToDiscard: [CBPeripheral]?

    /// Transmission power levels per discovered peripheral
    private var powerLevels: [UUID: Double] = [:]

    /// The computed distance from the discovered peripherals
    private var distancesCache: [UUID: Double] = [:]

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
                #if DEBUG
                    self.logger?.log("[Receiver]: scanning for \(self.serviceIds.map { $0.uuidString }.joined(separator: ", "))")
                #endif
            }
        }
    }

    /// Start the scanning service for nearby devices
    public func startScanning() {
        #if DEBUG
            logger?.log("[Receiver]: start Scanning")
        #endif
        if manager != nil {
            manager?.stopScan()
            if serviceIds != [] {
                manager?.scanForPeripherals(withServices: serviceIds, options: [
                    CBCentralManagerOptionShowPowerAlertKey: NSNumber(booleanLiteral: true),
                ])
                #if DEBUG
                    logger?.log("[Receiver]: scanning for \(serviceIds.map { $0.uuidString }.joined(separator: ", "))")
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
        #if DEBUG
            logger?.log("[Receiver]: stop Scanning")
            logger?.log("\n [Receiver]: going to sleep with \(pendingPeripherals) peripherals \n")
        #endif
        manager?.stopScan()
        manager = nil
        pendingPeripherals.removeAll()
    }
}

// MARK: CBCentralManagerDelegate implementation

extension BluetoothDiscoveryService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        #if DEBUG
            logger?.log(state: central.state, prefix: "[Receiver]: centralManagerDidUpdateState")
        #endif
        switch central.state {
        case .poweredOn where !serviceIds.isEmpty:
            #if DEBUG
                logger?.log("[Receiver]: scanning for \(serviceIds.map { $0.uuidString }.joined(separator: ", "))")
            #endif
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
        #if DEBUG
            logger?.log("[Receiver]: didDiscover: \(peripheral), rssi: \(RSSI)db")
        #endif
        if let power = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? Double {
            #if DEBUG
                logger?.log("[Receiver]: found TX-Power in Advertisment data: \(power)")
            #endif
            powerLevels[peripheral.identifier] = power
        } else {
            #if DEBUG
                logger?.log("[Receiver]: TX-Power not available")
            #endif
        }
        updateDistanceForPeripheral(peripheral, rssi: RSSI)
        try? storage.setDiscovery(uuid: peripheral.identifier)
        pendingPeripherals.append(peripheral)
        central.connect(peripheral, options: nil)
    }

    /// Calcualte and update the distance for a peripheral
    /// - Parameters:
    ///   - peripheral: The peripheral in question
    ///   - RSSI: The RSSI
    private func updateDistanceForPeripheral(_ peripheral: CBPeripheral, rssi RSSI: NSNumber) {
        let power = powerLevels[peripheral.identifier] ?? defaultPower

        let distance = pow(10, (power - Double(truncating: RSSI)) / 20)
        distancesCache[peripheral.identifier] = distance / 1000
        let distString = String(format: "%.2fm", distance / 1000)
        #if DEBUG
            logger?.log("[Receiver]: 📏 estimated distance is \(distString)")
        #endif
    }

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        #if DEBUG
            logger?.log("[Receiver]: didConnect: \(peripheral)")
        #endif
        try? storage.setConnection(uuid: peripheral.identifier)
        peripheral.delegate = self
        peripheral.discoverServices(serviceIds)
        peripheral.readRSSI()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let entity = try? storage.get(uuid: peripheral.identifier),
            let lastConnection = entity.lastConnection {
            if Date().timeIntervalSince(lastConnection) > BluetoothConstants.peripheralDisposeInterval {
                #if DEBUG
                    logger?.log("[Receiver]: didDisconnectPeripheral dispose because last connection was \(Date().timeIntervalSince(lastConnection))seconds ago")
                #endif
                pendingPeripherals.removeAll(where: { $0.identifier == peripheral.identifier })
                try? storage.discard(uuid: peripheral.identifier.uuidString)
                return
            }
        }

        var delay = 0
        if let error = error {
            #if DEBUG
                logger?.log("[Receiver]: didDisconnectPeripheral (unexpected): \(peripheral) with error: \(error)")
            #endif
        } else {
            #if DEBUG
                logger?.log("[Receiver]: didDisconnectPeripheral (successful): \(peripheral)")
            #endif

            // Do not re-connect to the same (iOS) peripheral right away again to save battery
            delay = BluetoothConstants.peripheralReconnectDelay
        }

        central.connect(peripheral, options: [
            CBConnectPeripheralOptionStartDelayKey: NSNumber(integerLiteral: delay),
        ])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        #if DEBUG
            logger?.log("[Receiver]: didFailToConnect: \(peripheral)")
            logger?.log("[Receiver]: didFailToConnect error: \(error.debugDescription)")
        #endif

        if let entity = try? storage.get(uuid: peripheral.identifier) {
            if let lastConnection = entity.lastConnection,
                Date().timeIntervalSince(lastConnection) > BluetoothConstants.peripheralDisposeInterval {
                #if DEBUG
                    logger?.log("[Receiver]: didFailToConnect dispose because last connection was \(Date().timeIntervalSince(lastConnection))seconds ago")
                #endif
                pendingPeripherals.removeAll(where: { $0.identifier == peripheral.identifier })
                try? storage.discard(uuid: peripheral.identifier.uuidString)
                return
            } else if Date().timeIntervalSince(entity.discoverTime) > BluetoothConstants.peripheralDisposeIntervalSinceDiscovery {
                #if DEBUG
                    logger?.log("[Receiver]: didFailToConnect dispose because connection never suceeded and was \(Date().timeIntervalSince(entity.discoverTime))seconds ago")
                #endif
                pendingPeripherals.removeAll(where: { $0.identifier == peripheral.identifier })
                try? storage.discard(uuid: peripheral.identifier.uuidString)
                return
            }
        }

        central.connect(peripheral, options: nil)
    }

    func centralManager(_: CBCentralManager, willRestoreState dict: [String: Any]) {
        #if DEBUG
            logger?.log("[Receiver]: CentralManager#willRestoreState")
        #endif
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
            #if DEBUG
                logger?.log("\n [Receiver]: CentralManager#willRestoreState restoring peripherals \(pendingPeripherals) discarded \(peripheralsToDiscard.debugDescription) \n")
            #endif
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error _: Error?) {
        updateDistanceForPeripheral(peripheral, rssi: RSSI)
    }
}

extension BluetoothDiscoveryService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            #if DEBUG
                logger?.log("[Receiver]: didDiscoverCharacteristicsFor" + error.localizedDescription)
            #endif
            return
        }
        let cbuuid = BluetoothConstants.characteristicsCBUUID
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == cbuuid }) else {
            return
        }
        peripheral.readValue(for: characteristic)
        #if DEBUG
            logger?.log("[Receiver]: found characteristic \(peripheral.name.debugDescription)")
        #endif
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            #if DEBUG
                logger?.log("[Receiver]: didUpdateValueFor " + error.localizedDescription)
            #endif
            manager?.cancelPeripheralConnection(peripheral)
            return
        }

        guard let data = characteristic.value else {
            #if DEBUG
                logger?.log("[Receiver]: → ❌ Could not read data from characteristic of \(peripheral.identifier) at \(Date())")
            #endif
            manager?.cancelPeripheralConnection(peripheral)
            return
        }

        guard data.count == 36 else {
            #if DEBUG
                logger?.log("[Receiver]: → ❌ Received wrong number of bytes (\(data.count) bytes) from \(peripheral.identifier) at \(Date())")
            #endif
            manager?.cancelPeripheralConnection(peripheral)
            return
        }

        #if DEBUG
            logger?.log("[Receiver]: → ✅ Received (\(data.count) bytes) from \(peripheral.identifier) at \(Date())")
        #endif
        try? delegate?.didDiscover(data: data, distance: distancesCache[peripheral.identifier])
        manager?.cancelPeripheralConnection(peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        #if DEBUG
            logger?.log("[Receiver]: didDiscoverServices for \(peripheral.identifier)")
        #endif
        if let error = error {
            #if DEBUG
                logger?.log(error.localizedDescription)
            #endif
            return
        }
        if let service = peripheral.services?.first(where: { serviceIds.contains($0.uuid) }) {
            peripheral.discoverCharacteristics([BluetoothConstants.characteristicsCBUUID], for: service)
        } else {
            #if DEBUG
                logger?.log("[Receiver]: No service found 🤬")
            #endif
            try? storage.discard(uuid: peripheral.identifier.uuidString)
            manager?.cancelPeripheralConnection(peripheral)
        }
    }
}
