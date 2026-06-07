import Foundation

struct ConversationDTO: Codable, Sendable {
    let id: String
    let participantIds: [String]
    let participantNames: [String: String]
    let lastMessage: String
    let lastMessageAt: String
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case participantIds = "participant_ids"
        case participantNames = "participant_names"
        case lastMessage = "last_message"
        case lastMessageAt = "last_message_at"
        case unreadCount = "unread_count"
    }
}
