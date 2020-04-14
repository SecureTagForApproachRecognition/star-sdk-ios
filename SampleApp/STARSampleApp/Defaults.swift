//

import Foundation

/// UserDefaults Storage Singleton
class Default {
    static var shared = Default()
    var store = UserDefaults.standard

    /// Current infection status
    var identifierPrefix: String? {
        get {
            return store.string(forKey: "ch.ubique.starsdk.sampleapp.identifierPrefix")
        }
        set(newValue) {
            store.set(newValue, forKey: "ch.ubique.starsdk.sampleapp.identifierPrefix")
        }
    }

    var reconnectionDelay: Int {
        get {
            return (store.object(forKey: "ch.ubique.starsdk.sampleapp.reconnectionDelay") as? Int) ?? 60 * 5
        }
        set(newValue) {
            store.set(newValue, forKey: "ch.ubique.starsdk.sampleapp.reconnectionDelay")
        }
    }

    enum TracingMode: Int {
        case none = 0
        case active = 1
        case activeReceiving = 2
        case activeAdvertising = 3
    }

    var tracingMode: TracingMode {
        get {
            let mode = (store.object(forKey: "ch.ubique.starsdk.sampleapp.tracingMode") as? Int) ?? 0
            return TracingMode(rawValue: mode) ?? .none
        }
        set(newValue) {
            store.set(newValue.rawValue, forKey: "ch.ubique.starsdk.sampleapp.tracingMode")
        }
    }
}
