import Foundation
import CoreKit

final class MessageRepository: MessageRepositoryProtocol, @unchecked Sendable {
    private let remoteDataSource: MessageRemoteDataSourceProtocol
    private let localDataSource: MessageLocalDataSourceProtocol
    private let webSocketClient: WebSocketClientProtocol
    private let pendingQueue: PendingMessageQueue
    private let decoder = JSONDecoder()

    init(
        remoteDataSource: MessageRemoteDataSourceProtocol,
        localDataSource: MessageLocalDataSourceProtocol,
        webSocketClient: WebSocketClientProtocol,
        pendingQueue: PendingMessageQueue
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
        self.webSocketClient = webSocketClient
        self.pendingQueue = pendingQueue
    }

    // Yields cached messages first, then streams live updates from WebSocket.
    // Never throws — the stream silently terminates on disconnect.
    func messages(conversationId: String) -> AsyncStream<[Message]> {
        AsyncStream { continuation in
            Task {
                let cached = await localDataSource.messages(conversationId: conversationId)
                var accumulated = cached.compactMap { MessageMapper.toDomain($0) }
                continuation.yield(accumulated)

                // WebSocket receive — outbound send uses HTTP POST.
                for await payload in webSocketClient.subscribe(channel: "conv-\(conversationId)") {
                    guard
                        let data = payload.data(using: .utf8),
                        let event = try? self.decoder.decode(ChatEventDTO.self, from: data)
                    else { continue }

                    switch event.type {
                    case "message.new":
                        guard let dto = event.message, let msg = MessageMapper.toDomain(dto) else { continue }
                        await self.localDataSource.save(dto)
                        accumulated.append(msg)
                        continuation.yield(accumulated)
                    case "message.deleted":
                        guard let dto = event.message else { continue }
                        accumulated.removeAll { $0.id == dto.id }
                        continuation.yield(accumulated)
                    default:
                        break
                    }
                }
                continuation.finish()
            }
        }
    }

    // HTTP POST for outbound. WebSocket is receive-only — server pushes the
    // confirmed message back to all participants including the sender.
    func send(request: SendMessageRequest) async throws -> Message {
        let apiRequest = SendMessageAPIRequest(from: request)
        do {
            let dto = try await remoteDataSource.send(apiRequest)
            await localDataSource.save(dto)
            guard let message = MessageMapper.toDomain(dto) else { throw ChatError.decodingFailed }
            return message
        } catch is ChatError {
            throw ChatError.decodingFailed
        } catch {
            // Network failure — persist to offline queue, surface pending state to ViewModel.
            let pending = PendingMessageDTO(
                id: request.clientId,
                conversationId: request.conversationId,
                type: request.content.type,
                text: request.content.textValue,
                imageURL: nil,
                aspectRatio: nil,
                audioDuration: nil,
                audioURL: nil,
                queuedAt: ISO8601DateFormatter().string(from: Date())
            )
            await pendingQueue.enqueue(pending)
            throw ChatError.messageQueued
        }
    }

    func fetchHistory(request: FetchMessagesRequest) async throws -> [Message] {
        let dtos = try await remoteDataSource.fetchHistory(conversationId: request.path.conversationId)
        let messages = dtos.compactMap { MessageMapper.toDomain($0) }
        for dto in dtos { await localDataSource.save(dto) }
        return messages
    }

    // Called by ChatCoordinator on app foreground / WebSocket reconnect.
    // Re-queues items that still fail so the next flush can retry them.
    func flushPending(conversationId: String) async {
        let pending = await pendingQueue.dequeue(conversationId: conversationId)
        for item in pending {
            let apiRequest = SendMessageAPIRequest(from: item)
            if let dto = try? await remoteDataSource.send(apiRequest) {
                await localDataSource.save(dto)
            } else {
                await pendingQueue.enqueue(item)
            }
        }
    }
}
