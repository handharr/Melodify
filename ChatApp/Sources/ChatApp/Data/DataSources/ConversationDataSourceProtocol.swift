import Foundation

protocol ConversationDataSourceProtocol: Sendable {
    func fetchAll() async throws -> [ConversationDTO]
}
