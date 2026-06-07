import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatUIModel] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let conversationId: String
    private let currentUserId: String
    private let participantNames: [String: String]

    private let streamMessages: StreamMessagesUseCase
    private let sendMessage: SendMessageUseCase
    private let flushPending: FlushPendingMessagesUseCase

    private var streamTask: Task<Void, Never>?

    init(
        conversationId: String,
        currentUserId: String,
        participantNames: [String: String],
        streamMessages: StreamMessagesUseCase,
        sendMessage: SendMessageUseCase,
        flushPending: FlushPendingMessagesUseCase
    ) {
        self.conversationId = conversationId
        self.currentUserId = currentUserId
        self.participantNames = participantNames
        self.streamMessages = streamMessages
        self.sendMessage = sendMessage
        self.flushPending = flushPending
    }

    func viewDidAppear() {
        startStream()
        Task { await flushPending.execute(conversationId: conversationId) }
    }

    func viewDidDisappear() {
        streamTask?.cancel()
        streamTask = nil
    }

    func send(text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Optimistic insert — shows immediately with "pending" status.
        let clientId = UUID().uuidString
        let pending = ChatUIModelMapper.pendingText(text, clientId: clientId)
        messages.append(pending)

        Task { [weak self] in
            guard let self else { return }
            let request = SendMessageRequest(conversationId: conversationId, content: .text(text))
            do {
                _ = try await sendMessage.execute(request: request)
                // WebSocket will deliver the confirmed message back — stream handles the update.
            } catch ChatError.messageQueued {
                // Already in offline queue — pending indicator stays, no error shown.
            } catch {
                errorMessage = "Failed to send. Tap to retry."
            }
        }
    }

    // MARK: - Private

    private func startStream() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            for await batch in streamMessages.execute(conversationId: conversationId) {
                guard !Task.isCancelled else { break }
                messages = batch.map {
                    ChatUIModelMapper.map(
                        $0,
                        currentUserId: currentUserId,
                        senderName: participantNames[$0.senderId] ?? $0.senderId
                    )
                }
            }
        }
    }
}
