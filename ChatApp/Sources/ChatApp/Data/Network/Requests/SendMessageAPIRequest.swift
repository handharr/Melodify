import Foundation

// HTTP body for POST /conversations/{id}/messages.
// Named *APIRequest (not *Request) to avoid collision with Domain Request typealiases.
struct SendMessageAPIRequest: Sendable {
    let conversationId: String
    let clientId: String    // idempotency key
    let type: String
    let text: String?

    init(from request: SendMessageRequest) {
        self.conversationId = request.conversationId
        self.clientId = request.clientId
        self.type = request.content.type
        self.text = request.content.textValue
    }

    init(from pending: PendingMessageDTO) {
        self.conversationId = pending.conversationId
        self.clientId = pending.id
        self.type = pending.type
        self.text = pending.text
    }
}
