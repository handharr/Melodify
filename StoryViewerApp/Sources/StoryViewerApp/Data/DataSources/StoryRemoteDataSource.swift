import Foundation
import CoreKit

protocol StoryRemoteDataSourceProtocol: Sendable {
    func fetchStories(after cursor: Int?) async throws -> [StoryDTO]
}

final class StoryRemoteDataSource: StoryRemoteDataSourceProtocol, Sendable {
    private let client: APIClientProtocol
    private let baseURL = URL(string: "https://api.example.com/stories")!

    init(client: APIClientProtocol) {
        self.client = client
    }

    func fetchStories(after cursor: Int?) async throws -> [StoryDTO] {
        // Real: GET /stories?after={cursor}
        // Practice stub: returns empty — seed data lives in StoryLocalDataSource.
        return []
    }
}
