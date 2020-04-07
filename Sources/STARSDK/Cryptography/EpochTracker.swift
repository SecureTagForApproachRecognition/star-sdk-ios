//  Created by Loïc Gardiol on 30.03.20.

import Foundation

struct EpochTracker {
    
    private let epochDidIncrement: () -> Void
    
    init(epochDidIncrement: @escaping () -> Void)  {
        self.epochDidIncrement = epochDidIncrement
        self.rescheduleTimer()
    }
    
    private func rescheduleTimer() {
        Timer.scheduledTimer(withTimeInterval: {
            let currentEpoch = Epoch.current
            let nextEpoch = currentEpoch.next
            let currentTimeinterval = Date().timeIntervalSince1970
            return nextEpoch.timestamp - currentTimeinterval
        }(), repeats: false, block: { (_) in
            self.epochDidIncrement()
            self.rescheduleTimer()
        })
    }
}

struct Epoch: Codable, CustomStringConvertible {
    let index: UInt32
    let timestamp: TimeInterval
    
    init(index: UInt32) {
        self.index = index
        self.timestamp = GlobalParameters.epoch0TimeInterval + (Double(index) * GlobalParameters.epochDuration)
    }
    
    init?(timestamp: TimeInterval) {
        if timestamp < GlobalParameters.epoch0TimeInterval {
            return nil
        }
        self.timestamp = timestamp
        self.index = UInt32((timestamp - GlobalParameters.epoch0TimeInterval) / GlobalParameters.epochDuration)
    }
    
    static var current: Epoch {
        let currentTimeinterval = Date().timeIntervalSince1970
        let diff = currentTimeinterval - GlobalParameters.epoch0TimeInterval
        return Epoch(index: UInt32(floor(diff / GlobalParameters.epochDuration)))
    }
    
    var next: Epoch {
        return Epoch(index: self.index + 1)
    }
    
    var previous: Epoch? {
        if self.timestamp - GlobalParameters.epochDuration < GlobalParameters.epoch0TimeInterval {
            return nil
        }
        return Epoch(index: self.index - 1)
    }
    
    var description: String {
        return "<Epoch index: \(self.index)>"
    }
    
    static func <(lhs: Epoch, rhs: Epoch) -> Bool {
        return lhs.index < rhs.index
    }
    
    static func <=(lhs: Epoch, rhs: Epoch) -> Bool {
        return lhs.index <= rhs.index
    }
    
    static func >(lhs: Epoch, rhs: Epoch) -> Bool {
        return lhs.index > rhs.index
    }
    
    static func ==(lhs: Epoch, rhs: Epoch) -> Bool {
        return lhs.index == rhs.index
    }
    
    static func !=(lhs: Epoch, rhs: Epoch) -> Bool {
        return lhs.index != rhs.index
    }
}
