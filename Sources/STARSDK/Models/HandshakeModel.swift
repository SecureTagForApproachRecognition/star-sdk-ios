import Foundation

/// A model for the digital handshake
struct HandshakeModel {
    /// The timestamp of the handshake
    let timestamp: Date
    /// The STAR token exchanged during the handshake
    let star: Data
    /// The TX Power Level of both handshaking parties
    let TXPowerlevel: Double?
    /// The RSSI of both handshaking parties
    let RSSI: Double?
    /// If the handshake is associated with a known exposed case
    let knownCaseId: Int?

    // iOS sends at 12bm? Android seems to vary between -1dbm (HIGH_POWER) and -21dbm (LOW_POWER)
    private let defaultPower = 12.0

    /// Calcualte an estimation of the distance separating the two devices when a handshake happens
    /// - Parameters:
    ///   - peripheral: The peripheral in question
    ///   - RSSI: The RSSI
    var distance: Double? {
        guard let RSSI = RSSI else {
            return nil
        }
        let power = TXPowerlevel ?? defaultPower
        let distance = pow(10, (power - RSSI) / 20)
        return distance / 1000
    }
}
