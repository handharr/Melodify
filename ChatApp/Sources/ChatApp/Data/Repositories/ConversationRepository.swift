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
}
