import Foundation

// Mirrors API/local JSON shape exactly. Optionals here reflect the wire format —
// not the domain model. The Mapper is the only place that decides what's valid.
struct MessageDTO: Codable, Sendable {
    let id: String
    let conversationId: String
    let senderId: String
    let sequence: Int       // server-assigned, monotonic per conversation
    let type: String        // "text" | "image" | "audio" | "deleted"
    let text: String?
    let imageURL: String?
    let aspectRatio: CGFloat?
    let audioDuration: TimeInterval?
    let audioURL: String?
    let createdAt: String
    let status: String      // "pending" | "sent" | "delivered" | "read"

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case sequence
        case type
        case text
        case imageURL = "image_url"
        case aspectRatio = "aspect_ratio"
        case audioDuration = "audio_duration"
        case audioURL = "audio_url"
        case createdAt = "created_at"
        case status
    }
}
