//

import Foundation

/// UserDefaults Storage Singleton
class Default {
    static var shared = Default()
    var store = UserDefaults.standard

    /// Last date a backend sync happend
    var lastSync: Date? {
        get {
            return store.object(forKey: "ch.ubique.starsdk.lastsync") as? Date
        }
        set(newValue) {
            store.set(newValue, forKey: "ch.ubique.starsdk.lastsync")
        }
    }

    /// Current infection status
    var infectionStatus: InfectionStatus {
        get {
            return InfectionStatus(rawValue: store.integer(forKey: "ch.ubique.starsdk.InfectionStatus")) ?? .healthy
        }
        set(newValue) {
            store.set(newValue.rawValue, forKey: "ch.ubique.starsdk.InfectionStatus")
        }
    }
}
