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
}
