import Foundation

// Called by ChatCoordinator on app foreground or WebSocket reconnect.
// Iterates the offline queue and retries HTTP POST for each pending message.
final class FlushPendingMessagesUseCase: Sendable {
    private let repository: MessageRepositoryProtocol

    init(repository: MessageRepositoryProtocol) {
        self.repository = repository
    }

    func execute(conversationId: String) async {
        await repository.flushPending(conversationId: conversationId)
    }
}
