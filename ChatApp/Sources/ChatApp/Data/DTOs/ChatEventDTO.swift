import Foundation

// WebSocket envelope payload. The channel multiplexing layer (WebSocketClient)
// has already stripped the outer envelope — this is the inner payload JSON.
struct ChatEventDTO: Codable, Sendable {
    let type: String    // "message.new" | "message.updated" | "message.deleted"
    let message: MessageDTO?
}
