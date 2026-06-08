import UIKit

final class LoadStoryImageUseCase: Sendable {
    private let repository: StoryRepositoryProtocol

    init(repository: StoryRepositoryProtocol) {
        self.repository = repository
    }

    func execute(url: URL) async throws -> UIImage {
        try await repository.loadImage(url: url)
    }
}
