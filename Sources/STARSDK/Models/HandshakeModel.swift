import Foundation

/// A model for the digital handshake
struct HandshakeModel {
    /// The timestamp of the handshake
    let timestamp: Date
    /// The STAR token exchanged during the handshake
    let star: Data
    /// The distance of both handshaking parties
    let distance: Double?
    /// If the handshake is associated with a known exposed case
    let knownCaseId: Int?
}
