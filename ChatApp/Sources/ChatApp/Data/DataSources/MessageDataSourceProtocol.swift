import Foundation

protocol MessageLocalDataSourceProtocol: Sendable {
    func messages(conversationId: String) async -> [MessageDTO]
    func save(_ dto: MessageDTO) async
    func updateStatus(id: String, status: String) async
}

protocol MessageRemoteDataSourceProtocol: Sendable {
    func fetchHistory(conversationId: String) async throws -> [MessageDTO]
    func send(_ request: SendMessageAPIRequest) async throws -> MessageDTO
}
