//

/// This is used to differentiate between production and calibration mode
public enum STARMode {
    case production
    case calibration

    static var current: STARMode = .production
}
