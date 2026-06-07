import Foundation
import CoreKit

final class MessageRemoteDataSource: MessageRemoteDataSourceProtocol, Sendable {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchHistory(conversationId: String) async throws -> [MessageDTO] {
        // In a real app: GET /api/v1/conversations/{conversationId}/messages
        // Returning empty here since the local mock covers the demo scenario.
        return []
    }

    func send(_ request: SendMessageAPIRequest) async throws -> MessageDTO {
        // In a real app: POST /api/v1/conversations/{conversationId}/messages
        // Body: { client_id, type, text?, image_url?, ... }
        // Returns the server-confirmed MessageDTO with status "sent".
        //
        // We synthesise a response here so the flow compiles end-to-end
        // without a live server.
        return MessageDTO(
            id: request.clientId,
            conversationId: request.conversationId,
            senderId: "me",
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
