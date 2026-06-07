import Foundation

enum ConversationMapper {
    static func toDomain(_ dto: ConversationDTO) -> Conversation? {
        guard let date = ISO8601DateFormatter().date(from: dto.lastMessageAt) else { return nil }
        return Conversation(
            id: dto.id,
            participantIds: dto.participantIds,
            participantNames: dto.participantNames,
            lastMessage: dto.lastMessage,
            lastMessageAt: date,
            unreadCount: dto.unreadCount
        )
    }
}
