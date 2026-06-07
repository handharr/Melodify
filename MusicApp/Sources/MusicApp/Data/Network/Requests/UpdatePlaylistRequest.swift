import Foundation

struct UpdatePlaylistRequest: Encodable, Sendable {
    let id: Int
    let name: String
    let description: String

    // id is a path param — excluded from the encoded body
    enum CodingKeys: String, CodingKey {
        case name
        case description
    }
}
