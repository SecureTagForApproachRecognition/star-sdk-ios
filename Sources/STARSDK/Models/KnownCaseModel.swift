import Foundation

/// A model for known cases
struct KnownCaseModel: Decodable {
    /// The identifier of the case
    let id: Int?
    /// The private key of the case
    let key: Data
    /// The day the known case was set as exposed
    let onset: String

    enum CodingKeys: String, CodingKey {
        case id, key, onset
    }
}

// MARK: Codable implementation

extension KnownCaseModel {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(Int.self, forKey: .id)
        key = try values.decode(Data.self, forKey: .key)
        onset = try values.decode(String.self, forKey: .onset)
    }
}
