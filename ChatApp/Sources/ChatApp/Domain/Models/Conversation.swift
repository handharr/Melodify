import Foundation

struct Conversation: Sendable, Equatable {
    let id: String
    let participantIds: [String]
    let participantNames: [String: String]
    let lastMessage: String
    let lastMessageAt: Date
    let unreadCount: Int
}
