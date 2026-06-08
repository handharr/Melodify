import Foundation
import CoreKit

final class MessageRemoteDataSource: MessageRemoteDataSourceProtocol, Sendable {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchMessages(conversationId: String, before messageId: String?, limit: Int) async throws -> [MessageDTO] {
        // Real: GET /api/v1/conversations/{conversationId}/messages?before={messageId}&limit={n}
        // Stub: local mock JSON covers the demo; pagination returns empty (FRC re-yields from cache).
        return []
    }

    func send(_ request: SendMessageAPIRequest) async throws -> MessageDTO {
        // Real: POST /api/v1/conversations/{conversationId}/messages
        // Synthesised response — struct types and interface contract match what a real server returns.
        return MessageDTO(
            id: request.clientId,
            conversationId: request.conversationId,
            senderId: "me",
            sequence: 0,    // stub — server assigns a real monotonic value
            type: request.type,
            text: request.text,
            imageURL: nil,
            aspectRatio: nil,
            audioDuration: nil,
            audioURL: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            status: "sent"
        )
    }
}
