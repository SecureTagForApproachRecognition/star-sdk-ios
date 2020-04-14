//

import Foundation

struct SecretKey: Codable, CustomStringConvertible {
    let epoch: Epoch
    let keyData: Data

    var description: String {
        return "<SecretKey_\(epoch): \(keyData.hexEncodedString)>"
    }
}
