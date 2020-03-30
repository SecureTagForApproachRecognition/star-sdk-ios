import Foundation

/// A model for known cases
struct KnownCaseModel: Decodable {
    static let dayDecoderUserInfoKey = CodingUserInfoKey(rawValue: "KnownCaseModel.day")!
    /// All actions a know case can have
    enum Action: String, Decodable {
        /// Add a record of know case
        case ADD
        /// Remove a record of a known case if present
        case REMOVE
    }

    /// The identifier of the case
    let id: Int
    /// The action to be applied
    let action: Action?
    /// The private key of the case
    let key: Data
    /// The day the known case was listed in
    let day: String

    enum CodingKeys: String, CodingKey {
        case id, action, key
    }
}

// MARK: Codable implementation

extension KnownCaseModel {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(Int.self, forKey: .id)
        action = try values.decode(Action.self, forKey: .action)
        key = try values.decode(Data.self, forKey: .key)
        day = decoder.userInfo[KnownCaseModel.dayDecoderUserInfoKey]! as! String
    }
}
