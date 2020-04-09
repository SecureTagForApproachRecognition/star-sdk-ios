import Foundation

/// The environment of the app
public enum Enviroment {
    /// Production environment
    case prod
    /// A development environment
    case dev

    /// The endpoint for the discovery
    var discoveryEndpoint: URL {
        switch self {
        case .prod:
            return URL(string: "https://raw.githubusercontent.com/SecureTagForApproachRecognition/discovery/master/discovery.json")!
        case .dev:
            return URL(string: "https://raw.githubusercontent.com/SecureTagForApproachRecognition/discovery/master/discovery_dev.json")!
        }
    }
}
