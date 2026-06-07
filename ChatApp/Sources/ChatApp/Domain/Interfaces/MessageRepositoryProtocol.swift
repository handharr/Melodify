import Foundation

protocol MessageRepositoryProtocol: Sendable {
    // Returns cached messages immediately, then streams updates as WebSocket events arrive.
    // Stream never throws — errors are silently swallowed and the stream terminates on disconnect.
    func messages(conversationId: String) -> AsyncStream<[Message]>

    // HTTP POST for outbound send. WebSocket is receive-only.
    // Throws ChatError.messageQueued if offline — caller should surface a "pending" indicator.
    func send(request: SendMessageRequest) async throws -> Message

    // Loads historical messages from remote. Called once on screen open.
    func fetchHistory(request: FetchMessagesRequest) async throws -> [Message]

    // Retries all queued messages for the given conversation.
    // Called by coordinator on app foreground / WebSocket reconnect.
    func flushPending(conversationId: String) async
}
