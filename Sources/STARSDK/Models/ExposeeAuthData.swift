import Foundation

/// Model for the authentication data provided by health institutes to verify test results
struct ExposeeAuthData: Encodable {
    /// Authentication data used to verify the test result (base64 encoded)
    let value: String
}
