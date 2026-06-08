import Foundation

struct StoryDTO: Codable, Sendable {
    let photoID: Int
    let photoURL: String
    let profilePicURL: String
    let authorName: String
    let createdAt: Int   // Unix timestamp
    let expireAt: Int    // Unix timestamp
}
