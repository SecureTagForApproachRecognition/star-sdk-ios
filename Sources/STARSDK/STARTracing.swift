import Foundation

/// A delegate for the STAR tracing
public protocol STARTracingDelegate: AnyObject {
    /// The state has changed
    /// - Parameter state: The new state
    func STARTracingStateChanged(_ state: TracingState)
    /// An error has occurred
    /// - Parameter error: The error
    func errorOccured(_ error: STARTracingErrors)
}

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

        switch mode {
        case let .calibration(identifierPrefix):
            logger?.log("Setting identifier Prefix to \(identifierPrefix)")
        default:
            break
        }
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

    /// The logger
    public static var logger: LoggingDelegate? {
        set {
            instance?.logger = newValue
        }
        get {
            instance.logger
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

    /// tell the SDK that the user was expose
    /// - Parameters:
    ///   - customJSON: customJson to pass to the backen
    ///   - callback: callback
    public static func iWasExposed(customJSON: String?, callback: @escaping (Result<Void, STARTracingErrors>) -> Void) {
        guard let instance = instance else {
            fatalError("STARSDK not initialized call `initialize(with:delegate:)`")
        }
        instance.iWasExposed(customJSON: customJSON, callback: callback)
    }

    /// tell the SDK that the user is no longer exposed
    /// - Parameters:
    ///   - customJSON: customJson to pass to the backen
    ///   - callback: callback
    public static func iAmNoLongerExposed(customJSON: String?, callback: @escaping (Result<Void, STARTracingErrors>) -> Void) {
        guard let instance = instance else {
            fatalError("STARSDK not initialized call `initialize(with:delegate:)`")
        }
        instance.iAmNoLongerExposed(customJSON: customJSON, callback: callback)
    }

    /// reset the SDK
    public static func reset() throws {
        guard instance != nil else {
            fatalError("STARSDK not initialized call `initialize(with:delegate:)`")
        }
        try instance.reset()
        instance = nil
    }

    public static func getHandshakes(request: HandshakeRequest) throws -> HandshakeResponse {
        try instance.getHandshakes(request: request)
    }

    public static func numberOfHandshakes() throws -> Int {
        try instance.numberOfHandshakes()
    }
}
