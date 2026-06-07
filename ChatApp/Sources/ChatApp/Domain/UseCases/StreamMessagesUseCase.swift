import Foundation

// Streams messages for a conversation — starts with cache, updates live via WebSocket.
// Returns AsyncStream instead of a single value; FetchPolicy doesn't apply
// (streams always start from cache then go live by design).
final class StreamMessagesUseCase: Sendable {
    private let repository: MessageRepositoryProtocol

    init(repository: MessageRepositoryProtocol) {
        self.repository = repository
    }

    func execute(conversationId: String) -> AsyncStream<[Message]> {
        repository.messages(conversationId: conversationId)
    }
}
