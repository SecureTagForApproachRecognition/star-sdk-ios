//

/// This is used to differentiate between production and calibration mode
public enum STARMode: Equatable {
    case production
    case calibration(identifierPrefix: String)

    static var current: STARMode = .production
}
