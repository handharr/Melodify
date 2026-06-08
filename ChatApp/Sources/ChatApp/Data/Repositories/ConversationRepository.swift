import Foundation

final class ConversationRepository: ConversationRepositoryProtocol, Sendable {
    private let localDataSource: ConversationDataSourceProtocol

    init(localDataSource: ConversationDataSourceProtocol) {
        self.localDataSource = localDataSource
    }

    func fetchConversations(request: FetchConversationsRequest) async throws -> [Conversation] {
        let dtos = try await localDataSource.fetchAll()
        return dtos.compactMap { ConversationMapper.toDomain($0) }
    }

    func markRead(request: MarkReadRequest) async throws {
        // Real: POST /api/v1/conversations/{id}/read
        // Stub: no-op — server broadcasts conversation.unread_updated via WebSocket in production.
    }
}
