import Foundation

struct PlaylistDTO: Codable {
    let id: Int
    let name: String
    let description: String
    let trackIds: [Int]

    init(id: Int, name: String, description: String, trackIds: [Int] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.trackIds = trackIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        trackIds = (try? container.decode([Int].self, forKey: .trackIds)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case trackIds = "track_ids"
    }
}
