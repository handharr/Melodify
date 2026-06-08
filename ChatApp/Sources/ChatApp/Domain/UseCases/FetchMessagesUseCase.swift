import Foundation

// Cursor-based pagination. Fetches older messages and writes them to local storage.
// Does not return messages — the ObserveMessagesUseCase stream re-yields automatically
// when the local store is updated (same as NSFetchedResultsController.controllerDidChangeContent).
final class FetchMessagesUseCase: Sendable {
    private let repository: MessageRepositoryProtocol

    init(repository: MessageRepositoryProtocol) {
        self.repository = repository
    }

    func execute(_ request: FetchMessagesRequest) async throws {
        try await repository.fetchOlder(
            conversationId: request.path.conversationId,
            before: request.path.beforeMessageId,
            limit: request.path.limit
        )
    }
}
