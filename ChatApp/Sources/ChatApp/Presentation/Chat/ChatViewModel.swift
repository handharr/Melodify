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

    private let observeMessages: ObserveMessagesUseCase
    private let fetchMessages: FetchMessagesUseCase
    private let sendMessage: SendMessageUseCase
    private let markRead: MarkReadUseCase
    private let flushPending: FlushPendingMessagesUseCase

    private var observeTask: Task<Void, Never>?

    init(
        conversationId: String,
        currentUserId: String,
        participantNames: [String: String],
        observeMessages: ObserveMessagesUseCase,
        fetchMessages: FetchMessagesUseCase,
        sendMessage: SendMessageUseCase,
        markRead: MarkReadUseCase,
        flushPending: FlushPendingMessagesUseCase
    ) {
        self.conversationId = conversationId
        self.currentUserId = currentUserId
        self.participantNames = participantNames
        self.observeMessages = observeMessages
        self.fetchMessages = fetchMessages
        self.sendMessage = sendMessage
        self.markRead = markRead
        self.flushPending = flushPending
    }

    func viewDidAppear() {
        startObserving()
        Task { [weak self] in
            guard let self else { return }
            try? await markRead.execute(MarkReadRequest(path: .init(conversationId: conversationId)))
            await flushPending.execute(conversationId: conversationId)
        }
    }

    func viewDidDisappear() {
        observeTask?.cancel()
        observeTask = nil
    }

    // Called when the user scrolls to the top — loads the page before the oldest visible message.
    func loadMore(oldestMessageId: String) {
        Task { [weak self] in
            guard let self else { return }
            let request = FetchMessagesRequest(path: .init(
                conversationId: conversationId,
                beforeMessageId: oldestMessageId,
                limit: 50
            ))
            do {
                try await fetchMessages.execute(request)
                // ObserveMessagesUseCase stream re-yields automatically when local store updates.
            } catch {
                errorMessage = "Failed to load older messages."
            }
        }
    }

    func send(text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        Task { [weak self] in
            guard let self else { return }
            let request = SendMessageRequest(conversationId: conversationId, content: .text(text))
            do {
                _ = try await sendMessage.execute(request: request)
                // WebSocket delivers the confirmed message back — observation stream handles the update.
            } catch ChatError.messageQueued {
                // Already in offline queue — pending indicator stays, no error shown.
            } catch {
                errorMessage = "Failed to send. Tap to retry."
            }
        }
    }

    // MARK: - Private

    private func startObserving() {
        observeTask?.cancel()
        observeTask = Task { [weak self] in
            guard let self else { return }
            for await batch in observeMessages.execute(conversationId: conversationId) {
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
