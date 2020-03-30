import Foundation

/// The environment of the app
public enum Enviroment {
    /// Production environment
    case prod
    #if DEBUG
    /// A development environment
        case dev
    #endif

    /// The endpoint for the discovery
    var discoveryEndpoint: URL {
        switch self {
        case .prod:
            return URL(string: "https://raw.githubusercontent.com/SecureTagForApproachRecognition/discovery/master/discovery.json")!
        #if DEBUG
            case .dev:
                return URL(string: "https://raw.githubusercontent.com/SecureTagForApproachRecognition/discovery/master/discovery_dev.json")!
        #endif
        }
    }
}
