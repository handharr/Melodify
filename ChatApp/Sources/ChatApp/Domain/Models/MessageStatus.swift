import Foundation

enum MessageStatus: String, Codable, Sendable, Equatable {
    case pending   // locally queued, not yet sent
    case sent      // server acknowledged
    case delivered // delivered to recipient device
    case read      // recipient opened the conversation
}
