import Foundation

protocol MessageRepositoryProtocol: Sendable {
    // Returns cached messages immediately, then yields on every Core Data / local write.
    // Never throws — stream stays open until the caller cancels iteration.
    func observe(conversationId: String) -> AsyncStream<[Message]>

    // Cursor pagination — fetches older messages and writes them to local storage.
    // The observation stream re-yields automatically (FRC / observer pattern).
    func fetchOlder(conversationId: String, before messageId: String?, limit: Int) async throws

    // HTTP POST for outbound. WebSocket is receive-only.
    // Throws ChatError.messageQueued if offline — caller surfaces a "pending" indicator.
    func send(request: SendMessageRequest) async throws -> Message

    // Retries all queued messages for the given conversation.
    func flushPending(conversationId: String) async
}
