import Foundation

// Observes the live message list for a conversation.
// Returns an AsyncStream — never completes while the conversation is open.
// The name reflects domain intent (observing a resource), not the transport (WebSocket).
// FRC / local observer is the stream source; WebSocket is an invisible write path.
final class ObserveMessagesUseCase: Sendable {
    private let repository: MessageRepositoryProtocol

    init(repository: MessageRepositoryProtocol) {
        self.repository = repository
    }

    func execute(conversationId: String) -> AsyncStream<[Message]> {
        repository.observe(conversationId: conversationId)
    }
}
