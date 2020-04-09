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
}
