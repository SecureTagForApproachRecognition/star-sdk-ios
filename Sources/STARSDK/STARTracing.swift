import Foundation

/// A delegate for the STAR tracing
public protocol STARTracingDelegate: AnyObject {
    /// The state has changed
    /// - Parameter state: The new state
    func STARTracingStateChanged(_ state: TracingState)

    #if CALIBRATION
        func didAddLog(_ entry: LogEntry)
        func didAddHandshake(_ handshake: HandshakeModel)
    #endif
}

#if CALIBRATION
    public extension STARTracingDelegate {
        func didAddLog(_: LogEntry) {}
        func didAddHandshake(_: HandshakeModel) {}
    }
#endif

private var instance: STARSDK!

/// STARTracing
public enum STARTracing {
    /// initialize the SDK
    /// - Parameter appId: application identifier used for the discovery call
    /// - Parameter enviroment: enviroment to use
    public static func initialize(with appId: String, enviroment: Enviroment, mode: STARMode = .production) throws {
        guard instance == nil else {
            fatalError("STARSDK already initialized")
        }
        STARMode.current = mode
        instance = try STARSDK(appId: appId, enviroment: enviroment)
    }

    /// The delegate
    public static var delegate: STARTracingDelegate? {
        set {
            guard instance != nil else {
                fatalError("STARSDK not initialized")
            }
            instance.delegate = newValue
        }
        get {
            instance.delegate
        }
    }

    /// Starts Bluetooth tracing
    public static func startTracing() throws {
        guard let instance = instance else {
            fatalError("STARSDK not initialized call `initialize(with:delegate:)`")
        }
        try instance.startTracing()
    }

    /// Stops Bluetooth tracing
    public static func stopTracing() {
        guard let instance = instance else {
            fatalError("STARSDK not initialized call `initialize(with:delegate:)`")
        }
        instance.stopTracing()
    }

    /// Triggers sync with the backend to refresh the exposed list
    /// - Parameter callback: callback
    public static func sync(callback: ((Result<Void, STARTracingErrors>) -> Void)?) {
        guard let instance = instance else {
            fatalError("STARSDK not initialized call `initialize(with:delegate:)`")
        }
        instance.sync { result in
            DispatchQueue.main.async {
                callback?(result)
            }
        }
    }

    /// get the current status of the SDK
    /// - Parameter callback: callback
    public static func status(callback: (Result<TracingState, STARTracingErrors>) -> Void) {
        guard let instance = instance else {
            fatalError("STARSDK not initialized call `initialize(with:delegate:)`")
        }
        instance.status(callback: callback)
    }

    /// tell the SDK that the user was exposed
    /// - Parameters:
    ///   - onset: Start date of the exposure
    ///   - authString: Authentication string for the exposure change
    ///   - callback: callback
    public static func iWasExposed(onset: Date, authString: String, callback: @escaping (Result<Void, STARTracingErrors>) -> Void) {
        guard let instance = instance else {
            fatalError("STARSDK not initialized call `initialize(with:delegate:)`")
        }
        instance.iWasExposed(onset: onset, authString: authString, callback: callback)
    }

    /// reset the SDK
    public static func reset() throws {
        guard instance != nil else {
            fatalError("STARSDK not initialized call `initialize(with:delegate:)`")
        }
        try instance.reset()
        instance = nil
    }

    #if CALIBRATION
        public static func startAdvertising() throws {
            guard let instance = instance else {
                fatalError("STARSDK not initialized call `initialize(with:delegate:)`")
            }
            try instance.startAdvertising()
        }

        public static func startReceiving() throws {
            guard let instance = instance else {
                fatalError("STARSDK not initialized call `initialize(with:delegate:)`")
            }
            try instance.startReceiving()
        }

        public static func getHandshakes(request: HandshakeRequest) throws -> HandshakeResponse {
            try instance.getHandshakes(request: request)
        }

        public static func getLogs(request: LogRequest) throws -> LogResponse {
            guard let instance = instance else {
                fatalError("STARSDK not initialized call `initialize(with:delegate:)`")
            }
            return try instance.getLogs(request: request)
        }

        public static func numberOfHandshakes() throws -> Int {
            try instance.numberOfHandshakes()
        }

        public static var isInitialized: Bool {
            return instance != nil
        }

        public static var reconnectionDelay: Int {
            get {
                return BluetoothConstants.peripheralReconnectDelay
            }
            set {
                BluetoothConstants.peripheralReconnectDelay = newValue
            }
        }
    #endif
}
