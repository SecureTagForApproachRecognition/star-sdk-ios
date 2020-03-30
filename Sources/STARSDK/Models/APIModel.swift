import Foundation

/// Model of the known cases
struct KnownCasesResponse: Decodable {
    /// All exposed known cases
    let exposed: [KnownCaseModel]
}

/// Model of the discovery of services
struct DiscoveryServiceResponse: Codable {
    /// All available applications
    let applications: [TracingApplicationDescriptor]
}

/// Model for a record in the published services
struct TracingApplicationDescriptor: Codable {
    /// The app ID
    var appId: String
    /// A description of the service
    var description: String
    /// The backend base URL
    var backendBaseUrl: URL
    /// A list of base url
    var listBaseUrl: URL
    /// The associated buetooth GATT GUID
    var bleGattGuid: String
    /// The contact person for the record
    var contact: String
}
