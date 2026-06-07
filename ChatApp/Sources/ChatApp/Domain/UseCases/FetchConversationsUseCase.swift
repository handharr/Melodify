import Foundation

final class FetchConversationsUseCase: Sendable {
    private let repository: ConversationRepositoryProtocol

    init(repository: ConversationRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: FetchConversationsRequest) async throws -> [Conversation] {
        try await repository.fetchConversations(request: request)
    }
}
