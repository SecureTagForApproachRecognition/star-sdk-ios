//

/// This is used to differentiate between production and calibration mode
public enum STARMode: Equatable {
    case production
    #if CALIBRATION
        case calibration(identifierPrefix: String)
    #endif

    static var current: STARMode = .production
}
