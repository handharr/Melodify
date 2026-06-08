import Foundation

protocol ConversationRepositoryProtocol: Sendable {
    func fetchConversations(request: FetchConversationsRequest) async throws -> [Conversation]
    // POST /api/v1/conversations/{id}/read — server resets unread counter and broadcasts
    // conversation.unread_updated to all active devices via WebSocket.
    func markRead(request: MarkReadRequest) async throws
}
