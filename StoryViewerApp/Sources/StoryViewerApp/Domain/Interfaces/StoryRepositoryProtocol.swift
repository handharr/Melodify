import UIKit

protocol StoryRepositoryProtocol: Sendable {
    func fetchStories(request: FetchStoriesRequest) async throws -> [Story]
    func loadImage(url: URL) async throws -> UIImage
    func prefetchImage(url: URL)
}
