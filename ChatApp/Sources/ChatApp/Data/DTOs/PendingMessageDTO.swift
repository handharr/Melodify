import Foundation

// Persisted to disk (Documents/pending_messages.json) when a send fails.
// Structurally flat — mirrors MessageDTO's content fields so it can be
// retried via the same RemoteDataSource without re-encoding.
struct PendingMessageDTO: Codable, Sendable {
    let id: String          // clientId — doubles as idempotency key on retry
    let conversationId: String
    let type: String
    let text: String?
    let imageURL: String?
    let aspectRatio: CGFloat?
    let audioDuration: TimeInterval?
    let audioURL: String?
    let queuedAt: String    // ISO8601
}
