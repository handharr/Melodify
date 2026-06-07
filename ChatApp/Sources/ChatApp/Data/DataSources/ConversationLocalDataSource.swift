import Foundation

final class ConversationLocalDataSource: ConversationDataSourceProtocol, Sendable {
    func fetchAll() async throws -> [ConversationDTO] {
        guard let url = Bundle.module.url(forResource: "conversations", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? JSONDecoder().decode([ConversationDTO].self, from: data)) ?? []
    }
}
