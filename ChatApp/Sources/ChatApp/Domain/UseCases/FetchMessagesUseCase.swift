import Foundation

final class FetchMessagesUseCase: Sendable {
    private let repository: MessageRepositoryProtocol

    init(repository: MessageRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: FetchMessagesRequest) async throws -> [Message] {
        try await repository.fetchHistory(request: request)
    }
}
