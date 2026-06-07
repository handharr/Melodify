import Foundation
import Combine

@MainActor
final class ConversationListViewModel: ObservableObject {
    @Published private(set) var conversations: [ConversationUIModel] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let fetchConversations: FetchConversationsUseCase
    private let currentUserId: String

    init(fetchConversations: FetchConversationsUseCase, currentUserId: String = "me") {
        self.fetchConversations = fetchConversations
        self.currentUserId = currentUserId
    }

    func load() {
        Task { [weak self] in
            guard let self else { return }
            isLoading = true
            defer { isLoading = false }
            do {
                let request = FetchConversationsRequest(
                    query: FetchConversationsQuery(userId: currentUserId)
                )
                let result = try await fetchConversations.execute(request: request)
                conversations = result.map {
                    ConversationUIModelMapper.map($0, currentUserId: currentUserId)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
