import Foundation

struct Message: Sendable, Equatable {
    let id: String
    let conversationId: String
    let senderId: String
    let content: MessageContent
    let status: MessageStatus
    let sequence: Int       // server-assigned monotonic sequence per conversation
    let createdAt: Date
}
