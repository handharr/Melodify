import Foundation

// Marks a conversation as read. Server resets the unread counter and broadcasts
// conversation.unread_updated to all active devices — ConversationListViewModel
// receives the WebSocket event and clears the badge reactively.
final class MarkReadUseCase: Sendable {
    private let repository: ConversationRepositoryProtocol

    init(repository: ConversationRepositoryProtocol) {
        self.repository = repository
    }

    func execute(_ request: MarkReadRequest) async throws {
        try await repository.markRead(request: request)
    }
}
