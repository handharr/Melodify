import Foundation

protocol ConversationRepositoryProtocol: Sendable {
    func fetchConversations(request: FetchConversationsRequest) async throws -> [Conversation]
}
