import Foundation

protocol MessageLocalDataSourceProtocol: Sendable {
    // Returns cached messages immediately, then yields on every save/delete.
    // Mirrors what NSFetchedResultsController.controllerDidChangeContent does in the Core Data path.
    func observe(conversationId: String) -> AsyncStream<[MessageDTO]>
    func save(_ dto: MessageDTO) async
    func delete(id: String) async
    func updateStatus(id: String, status: String) async
}

protocol MessageRemoteDataSourceProtocol: Sendable {
    // nil beforeMessageId fetches the latest page.
    func fetchMessages(conversationId: String, before messageId: String?, limit: Int) async throws -> [MessageDTO]
    func send(_ request: SendMessageAPIRequest) async throws -> MessageDTO
}
