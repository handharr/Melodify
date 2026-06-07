import Foundation

final class SendMessageUseCase: Sendable {
    private let repository: MessageRepositoryProtocol

    init(repository: MessageRepositoryProtocol) {
        self.repository = repository
    }

    // Returns the sent Message. Throws ChatError.messageQueued if offline —
    // ViewModel should mark the message as pending, not show an error.
    func execute(request: SendMessageRequest) async throws -> Message {
        try await repository.send(request: request)
    }
}
