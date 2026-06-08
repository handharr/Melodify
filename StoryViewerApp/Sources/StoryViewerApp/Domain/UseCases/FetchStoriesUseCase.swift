import Foundation

final class FetchStoriesUseCase: Sendable {
    private let repository: StoryRepositoryProtocol

    init(repository: StoryRepositoryProtocol) {
        self.repository = repository
    }

    func execute(_ request: FetchStoriesRequest) async throws -> [Story] {
        try await repository.fetchStories(request: request)
    }
}
