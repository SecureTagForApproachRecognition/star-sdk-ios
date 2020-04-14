//

import Foundation
import os
import UIKit

/// Main class for handling SDK logic
class STARSDK {
    /// appId of this instance
    private let appId: String

    /// A service to broadcast bluetooth packets containing the STAR token
    private let broadcaster: BluetoothBroadcastService

    /// The discovery service responsible of scanning for nearby bluetooth devices offering the STAR service
    private let discoverer: BluetoothDiscoveryService

    /// matcher for STAR tokens
    private let matcher: STARMatcher

    /// databsase
    private let database: STARDatabase

    /// The STAR crypto algorithm
    private let starCrypto: STARCryptoModule

    /// Fetch the discovery data and stores it
    private let applicationSynchronizer: ApplicationSynchronizer

    /// Synchronizes data on known cases
    private let synchronizer: KnownCasesSynchronizer

    /// tracing service client
    private var cachedTracingServiceClient: ExposeeServiceClient?

    /// enviroemnt of this instance
    private let enviroment: Enviroment

    /// delegate
    public weak var delegate: STARTracingDelegate?

    #if CALIBRATION
        /// getter for identifier prefix for calibration mode
        private(set) var identifierPrefix: String {
            get {
                switch STARMode.current {
                case let .calibration(identifierPrefix):
                    return identifierPrefix
                default:
                    fatalError("identifierPrefix is only usable in calibration mode")
                }
            }
            set {}
        }
    #endif

    /// keeps track of  SDK state
    private var state: TracingState {
        didSet {
            Default.shared.infectionStatus = state.infectionStatus
            Default.shared.lastSync = state.lastSync
            DispatchQueue.main.async {
                self.delegate?.STARTracingStateChanged(self.state)
            }
        }
    }

    /// Initializer
    /// - Parameters:
    ///   - appId: application identifer to use for discovery call
    ///   - enviroment: enviroment to use
    init(appId: String, enviroment: Enviroment) throws {
        self.enviroment = enviroment
        self.appId = appId
        database = try STARDatabase()
        starCrypto = STARCryptoModule()!
        matcher = try STARMatcher(database: database, starCrypto: starCrypto)
        synchronizer = KnownCasesSynchronizer(appId: appId, database: database, matcher: matcher)
        applicationSynchronizer = ApplicationSynchronizer(enviroment: enviroment, storage: database.applicationStorage)
        broadcaster = BluetoothBroadcastService(starCrypto: starCrypto)
        discoverer = BluetoothDiscoveryService(storage: database.peripheralStorage)
        state = TracingState(numberOfHandshakes: (try? database.handshakesStorage.count()) ?? 0,
                             trackingState: .stopped,
                             lastSync: Default.shared.lastSync,
                             infectionStatus: Default.shared.infectionStatus)

        broadcaster.permissionDelegate = self
        discoverer.permissionDelegate = self
        discoverer.delegate = matcher
        matcher.delegate = self

        #if CALIBRATION
            broadcaster.logger = self
            discoverer.logger = self
            database.logger = self
        #endif

        print(database)

        try applicationSynchronizer.sync { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                if let desc = try? self.database.applicationStorage.descriptor(for: self.appId) {
                    let client = ExposeeServiceClient(descriptor: desc)
                    self.cachedTracingServiceClient = client
                }
            case let .failure(error):
                DispatchQueue.main.async {
                    self.state.trackingState = .inactive(error: error)
                    self.stopTracing()
                }
            }
        }
    }

    /// start tracing
    func startTracing() throws {
        state.trackingState = .active
        discoverer.startScanning()
        broadcaster.startService()
    }

    /// stop tracing
    func stopTracing() {
        discoverer.stopScanning()
        broadcaster.stopService()
        state.trackingState = .stopped
    }

    #if CALIBRATION
        func startAdvertising() throws {
            state.trackingState = .activeAdvertising
            broadcaster.startService()
        }

        func startReceiving() throws {
            state.trackingState = .activeReceiving
            discoverer.startScanning()
        }
    #endif

    /// Perform a new sync
    /// - Parameter callback: callback
    func sync(callback: ((Result<Void, STARTracingErrors>) -> Void)?) {
        getATracingServiceClient(forceRefresh: true) { [weak self] result in
            switch result {
            case let .failure(error):
                callback?(.failure(error))
                return
            case let .success(service):
                self?.synchronizer.sync(service: service) { [weak self] result in
                    if case .success = result {
                        self?.state.lastSync = Date()
                    }
                    callback?(result)
                }
            }
        }
    }

    /// get the current status of the SDK
    /// - Parameter callback: callback
    func status(callback: (Result<TracingState, STARTracingErrors>) -> Void) {
        try? state.numberOfHandshakes = database.handshakesStorage.count()
        callback(.success(state))
    }

    /// tell the SDK that the user was exposed
    /// - Parameters:
    ///   - onset: Start date of the exposure
    ///   - authString: Authentication string for the exposure change
    ///   - callback: callback
    func iWasExposed(onset: Date, authString: String, callback: @escaping (Result<Void, STARTracingErrors>) -> Void) {
        setExposed(onset: onset, authString: authString, callback: callback)
    }

    /// used to construct a new tracing service client
    private func getATracingServiceClient(forceRefresh: Bool, callback: @escaping (Result<ExposeeServiceClient, STARTracingErrors>) -> Void) {
        if forceRefresh == false, let cachedTracingServiceClient = cachedTracingServiceClient {
            callback(.success(cachedTracingServiceClient))
            return
        }
        try? applicationSynchronizer.sync { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                if let desc = try? self.database.applicationStorage.descriptor(for: self.appId) {
                    let client = ExposeeServiceClient(descriptor: desc)
                    self.cachedTracingServiceClient = client
                    callback(.success(client))
                } else {
                    callback(.failure(STARTracingErrors.CaseSynchronizationError))
                }
            case let .failure(error):
                callback(.failure(error))
            }
        }
    }

    /// update the backend with the new exposure state
    /// - Parameters:
    ///   - onset: Start date of the exposure
    ///   - authString: Authentication string for the exposure change
    ///   - callback: callback
    private func setExposed(onset: Date, authString: String, callback: @escaping (Result<Void, STARTracingErrors>) -> Void) {
        getATracingServiceClient(forceRefresh: false) { [weak self] result in
            guard let self = self else {
                return
            }
            switch result {
            case let .failure(error):
                DispatchQueue.main.async {
                    callback(.failure(error))
                }
            case let .success(service):
                do {
                    let block: ((Result<Void, STARTracingErrors>) -> Void) = { [weak self] result in
                        if case .success = result {
                            self?.state.infectionStatus = .infected
                        }
                        DispatchQueue.main.async {
                            callback(result)
                        }
                    }
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    let model = ExposeeModel(key: try self.starCrypto.getSecretKeyForPublishing(onsetDate: onset)!, onset: dateFormatter.string(from: onset), authData: ExposeeAuthData(value: authString))
                    service.addExposee(model, completion: block)

                } catch let error as STARTracingErrors {
                    DispatchQueue.main.async {
                        callback(.failure(error))
                    }
                } catch {
                    DispatchQueue.main.async {
                        callback(.failure(STARTracingErrors.CryptographyError(error: "Cannot get secret key")))
                    }
                }
            }
        }
    }

    /// reset the SDK
    func reset() throws {
        stopTracing()
        Default.shared.lastSync = nil
        Default.shared.infectionStatus = .healthy
        try database.emptyStorage()
        try database.destroyDatabase()
        starCrypto.reset()
    }

    #if CALIBRATION
        func getHandshakes(request: HandshakeRequest) throws -> HandshakeResponse {
            try database.handshakesStorage.getHandshakes(request)
        }

        func numberOfHandshakes() throws -> Int {
            try database.handshakesStorage.numberOfHandshakes()
        }

        func getLogs(request: LogRequest) throws -> LogResponse {
            return try database.loggingStorage.getLogs(request)
        }
    #endif
}

// MARK: STARMatcherDelegate implementation

extension STARSDK: STARMatcherDelegate {
    func didFindMatch() {
        state.infectionStatus = .exposed
    }

    func handShakeAdded(_ handshake: HandshakeModel) {
        if let newHandshaked = try? database.handshakesStorage.count() {
            state.numberOfHandshakes = newHandshaked
        }
        #if CALIBRATION
            delegate?.didAddHandshake(handshake)
        #endif
    }
}

// MARK: BluetoothPermissionDelegate implementation

extension STARSDK: BluetoothPermissionDelegate {
    func deviceTurnedOff() {
        state.trackingState = .inactive(error: .BluetoothTurnedOff)
    }

    func unauthorized() {
        state.trackingState = .inactive(error: .PermissonError)
    }
}

#if CALIBRATION
    extension STARSDK: LoggingDelegate {
        func log(type: LogType, _ string: String) {
            os_log("%@: %@", type.description, string)
            if let entry = try? database.loggingStorage.log(type: type, message: string) {
                delegate?.didAddLog(entry)
            }
        }
    }
#endif
