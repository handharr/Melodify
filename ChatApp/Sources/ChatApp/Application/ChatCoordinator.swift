import UIKit
import CoreKit

// Composition root for ChatApp. Builds the full dependency graph and owns navigation.
// FlushPendingMessagesUseCase is triggered on app foreground — the coordinator
// observes UIApplication.didBecomeActiveNotification so the retry logic lives here,
// not in any ViewController. Same coordinator handles APNs silent push and BGAppRefreshTask
// (wired by the host app) — all three triggers route to flushAllPendingMessages().
@MainActor
public final class ChatCoordinator {
    private let navigationController: UINavigationController
    nonisolated(unsafe) private var foregroundObserver: Any?

    private let webSocketClient: WebSocketClientProtocol

    // Shared across all open conversations for the module's lifetime.
    private let pendingQueue = PendingMessageQueue()
    private let messageLocalDataSource = MessageLocalDataSource()

    public init(webSocketClient: WebSocketClientProtocol, navigationController: UINavigationController) {
        self.webSocketClient = webSocketClient
        self.navigationController = navigationController
    }

    public func start() {
        let listVC = makeConversationListViewController()
        navigationController.pushViewController(listVC, animated: true)

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { [weak self] in await self?.flushAllPendingMessages() }
        }
    }

    deinit {
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Factory

    private func makeConversationListViewController() -> ConversationListViewController {
        let dataSource = ConversationLocalDataSource()
        let repository = ConversationRepository(localDataSource: dataSource)
        let useCase = FetchConversationsUseCase(repository: repository)
        let viewModel = ConversationListViewModel(fetchConversations: useCase)

        let vc = ConversationListViewController(viewModel: viewModel)
        vc.onSelectConversation = { [weak self] conversationId in
            self?.showChat(
                conversationId: conversationId,
                participantNames: ["me": "You", "user-alice": "Alice", "user-bob": "Bob"]
            )
        }
        return vc
    }

    private func showChat(conversationId: String, participantNames: [String: String]) {
        let remoteDataSource = MessageRemoteDataSource(client: APIClient())
        let messageRepository = MessageRepository(
            remoteDataSource: remoteDataSource,
            localDataSource: messageLocalDataSource,
            webSocketClient: webSocketClient,
            pendingQueue: pendingQueue
        )

        let conversationRepository = ConversationRepository(
            localDataSource: ConversationLocalDataSource()
        )

        let viewModel = ChatViewModel(
            conversationId: conversationId,
            currentUserId: "me",
            participantNames: participantNames,
            observeMessages: ObserveMessagesUseCase(repository: messageRepository),
            fetchMessages: FetchMessagesUseCase(repository: messageRepository),
            sendMessage: SendMessageUseCase(repository: messageRepository),
            markRead: MarkReadUseCase(repository: conversationRepository),
            flushPending: FlushPendingMessagesUseCase(repository: messageRepository)
        )

        let vc = ChatViewController(viewModel: viewModel)
        vc.title = participantNames.filter { $0.key != "me" }.first?.value ?? "Chat"
        navigationController.pushViewController(vc, animated: true)
    }

    // MARK: - Flush

    // Called on: didBecomeActiveNotification | APNs silent push | BGAppRefreshTask.
    // Uses pendingConversationIds() — O(pending conversations), not O(all conversations).
    func flushAllPendingMessages() async {
        let conversationIds = await pendingQueue.pendingConversationIds()
        for conversationId in conversationIds {
            let repository = MessageRepository(
                remoteDataSource: MessageRemoteDataSource(client: APIClient()),
                localDataSource: messageLocalDataSource,
                webSocketClient: webSocketClient,
                pendingQueue: pendingQueue
            )
            await FlushPendingMessagesUseCase(repository: repository).execute(conversationId: conversationId)
        }
    }
}
