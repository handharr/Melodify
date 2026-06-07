import UIKit
import CoreKit

// Composition root for ChatApp. Builds the full dependency graph and owns navigation.
// FlushPendingMessagesUseCase is triggered on app foreground — the coordinator
// observes UIApplication.didBecomeActiveNotification so the retry logic lives here,
// not in any ViewController.
public final class ChatCoordinator {
    private let navigationController: UINavigationController
    private var foregroundObserver: Any?

    // Shared infrastructure
    private let webSocketClient: WebSocketClientProtocol

    // Shared Data
    private let pendingQueue = PendingMessageQueue()
    private let messageLocalDataSource = MessageLocalDataSource()

    // navigationController is the host app's main nav — ChatCoordinator pushes onto it.
    public init(webSocketClient: WebSocketClientProtocol, navigationController: UINavigationController) {
        self.webSocketClient = webSocketClient
        self.navigationController = navigationController
    }

    @MainActor
    public func start() {
        let listVC = makeConversationListViewController()
        navigationController.pushViewController(listVC, animated: true)

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.flushAllPendingMessages()
        }
    }

    deinit {
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Factory

    @MainActor
    private func makeConversationListViewController() -> ConversationListViewController {
        let dataSource = ConversationLocalDataSource()
        let repository = ConversationRepository(localDataSource: dataSource)
        let useCase = FetchConversationsUseCase(repository: repository)
        let viewModel = ConversationListViewModel(fetchConversations: useCase)

        let vc = ConversationListViewController(viewModel: viewModel)
        vc.onSelectConversation = { [weak self] conversationId in
            self?.showChat(conversationId: conversationId, participantNames: ["me": "You", "user-alice": "Alice", "user-bob": "Bob"])
        }
        return vc
    }

    @MainActor
    private func showChat(conversationId: String, participantNames: [String: String]) {
        let remoteDataSource = MessageRemoteDataSource(client: APIClient())
        let repository = MessageRepository(
            remoteDataSource: remoteDataSource,
            localDataSource: messageLocalDataSource,
            webSocketClient: webSocketClient,
            pendingQueue: pendingQueue
        )

        let viewModel = ChatViewModel(
            conversationId: conversationId,
            currentUserId: "me",
            participantNames: participantNames,
            streamMessages: StreamMessagesUseCase(repository: repository),
            sendMessage: SendMessageUseCase(repository: repository),
            flushPending: FlushPendingMessagesUseCase(repository: repository)
        )

        let vc = ChatViewController(viewModel: viewModel)
        vc.title = participantNames.filter { $0.key != "me" }.first?.value ?? "Chat"
        navigationController.pushViewController(vc, animated: true)
    }

    // MARK: - Flush

    private func flushAllPendingMessages() {
        // In a real app: iterate all active conversations from the pending queue.
        // For demo: flush the two known conversation IDs.
        let conversations = ["conv-1", "conv-2"]
        conversations.forEach { conversationId in
            let remoteDataSource = MessageRemoteDataSource(client: APIClient())
            let repository = MessageRepository(
                remoteDataSource: remoteDataSource,
                localDataSource: messageLocalDataSource,
                webSocketClient: webSocketClient,
                pendingQueue: pendingQueue
            )
            let useCase = FlushPendingMessagesUseCase(repository: repository)
            Task { await useCase.execute(conversationId: conversationId) }
        }
    }
}
