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

    // Local observation is the single read path — mirrors NSFetchedResultsController.
    // WebSocket events write to local; local notifies all observers automatically.
    func observe(conversationId: String) -> AsyncStream<[Message]> {
        AsyncStream { continuation in
            // Task 1 — forward local data source stream → domain models
            let localTask = Task {
                for await dtos in localDataSource.observe(conversationId: conversationId) {
                    guard !Task.isCancelled else { break }
                    continuation.yield(dtos.compactMap { MessageMapper.toDomain($0) })
                }
                continuation.finish()
            }

            // Task 2 — WebSocket events → write to local → local observer fires → Task 1 re-yields
            let wsTask = Task {
                for await payload in webSocketClient.subscribe(channel: "conv-\(conversationId)") {
                    guard !Task.isCancelled,
                          let data = payload.data(using: .utf8),
                          let event = try? self.decoder.decode(ChatEventDTO.self, from: data)
                    else { continue }

                    switch event.type {
                    case "message.new":
                        if let dto = event.message { await self.localDataSource.save(dto) }
                    case "message.deleted":
                        if let dto = event.message { await self.localDataSource.delete(id: dto.id) }
                    default:
                        break
                    }
                }
            }

            continuation.onTermination = { _ in
                localTask.cancel()
                wsTask.cancel()
            }
        }
    }

    // Writes older messages to local storage; observation stream re-yields automatically.
    func fetchOlder(conversationId: String, before messageId: String?, limit: Int) async throws {
        let dtos = try await remoteDataSource.fetchMessages(
            conversationId: conversationId,
            before: messageId,
            limit: limit
        )
        for dto in dtos { await localDataSource.save(dto) }
    }

    // HTTP POST for outbound. WebSocket is receive-only.
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
