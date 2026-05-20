import Foundation

struct PlaylistDTO: Codable {
    let id: Int
    let name: String
    let description: String
}

struct CreatePlaylistRequestDTO: Encodable {
    let name: String
    let description: String
    let trackIds: [Int]

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case trackIds = "track_ids"
    }
}

struct UpdatePlaylistRequestDTO: Encodable {
    let name: String
    let description: String

    enum CodingKeys: String, CodingKey {
        case name
        case description
    }
}
