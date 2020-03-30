import Foundation

/// A protocol for providing STAR crypto services
protocol STARCryptoProtocol: class {
    /// Generate a new TOTP
    func newTOTP() throws -> Data
    /// Validate if a totp was encrypted with the provided key
    /// - Parameters:
    ///   - key: The key to check
    ///   - star: The STAR TOTP to be checked
    func validate(key: Data, star: Data) -> Bool
    /// Returns the secret key used to sign all TOTP
    func getSecretKey() throws -> Data
    /// Reset the key in the keychain
    func reset() throws
}
