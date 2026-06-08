import Foundation

final class PrefetchStoryImageUseCase: Sendable {
    private let repository: StoryRepositoryProtocol

    init(repository: StoryRepositoryProtocol) {
        self.repository = repository
    }

    func execute(url: URL) {
        repository.prefetchImage(url: url)
    }
}
