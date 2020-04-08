//  Created by Loïc Gardiol on 30.03.20.

import Foundation

struct GlobalParameters {
    static let epoch0TimeInterval: TimeInterval = 1585475061.0
    static let epochDuration: TimeInterval = 15.0 * 60.0
    static let nbStoredEpochs: UInt32 = 21
    
    static let SecretKeyNbBytes = 32
    static let EphIDNbBytes = 16
}
