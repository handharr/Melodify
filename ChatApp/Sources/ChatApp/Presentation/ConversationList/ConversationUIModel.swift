import Foundation

struct ConversationUIModel: Hashable {
    let id: String
    let title: String           // other participant's name
    let lastMessage: String
    let timestamp: String
    let unreadCount: Int
    let hasUnread: Bool
}

enum ConversationUIModelMapper {
    static func map(_ conversation: Conversation, currentUserId: String) -> ConversationUIModel {
        let otherName = conversation.participantNames
            .filter { $0.key != currentUserId }
            .first?.value ?? "Unknown"

        return ConversationUIModel(
            id: conversation.id,
            title: otherName,
            lastMessage: conversation.lastMessage,
            timestamp: formatDate(conversation.lastMessageAt),
            unreadCount: conversation.unreadCount,
            hasUnread: conversation.unreadCount > 0
        )
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
