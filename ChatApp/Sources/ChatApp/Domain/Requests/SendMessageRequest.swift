import Foundation

struct SendMessageRequest: Sendable {
    let conversationId: String
    let content: MessageContent
    // UUID generated at the call site — idempotency key ensures the server
    // returns the existing record if the same request is retried after a timeout.
    let clientId: String

    init(conversationId: String, content: MessageContent) {
        self.conversationId = conversationId
        self.content = content
        self.clientId = UUID().uuidString
    }
}
