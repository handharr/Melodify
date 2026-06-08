import UIKit

private let throttleInterval: TimeInterval = 600  // 10 minutes

// FetchPolicy.cached interpretation: skip network if local data is < 10 min old.
// This is the only place that enforces the time threshold — ViewModel never decides.
// expireAt < now filtering also runs here on every read (not just on first fetch).
final class StoryRepository: StoryRepositoryProtocol, @unchecked Sendable {
    private let remoteDataSource: StoryRemoteDataSourceProtocol
    private let localDataSource: StoryLocalDataSourceProtocol
    private let imageDataSource: StoryImageDataSourceProtocol
    private let imageCache = NSCache<NSURL, UIImage>()

    init(
        remoteDataSource: StoryRemoteDataSourceProtocol,
        localDataSource: StoryLocalDataSourceProtocol,
        imageDataSource: StoryImageDataSourceProtocol
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
        self.imageDataSource = imageDataSource
    }

    func fetchStories(request: FetchStoriesRequest) async throws -> [Story] {
        if request.policy.allowStale && !request.policy.force {
            if let lastFetched = await localDataSource.lastFetchedAt(),
               Date().timeIntervalSince(lastFetched) < throttleInterval {
                return mapAndFilter(await localDataSource.read())
            }
        }

        let dtos = try await remoteDataSource.fetchStories(after: request.query.cursor)
        if !dtos.isEmpty {
            await localDataSource.write(dtos)
            await localDataSource.setLastFetchedAt(Date())
        }
        return mapAndFilter(await localDataSource.read())
    }

    func loadImage(url: URL) async throws -> UIImage {
        try await imageDataSource.loadImage(url: url)
    }

    func prefetchImage(url: URL) {
        imageDataSource.prefetch(url: url)
    }

    private func mapAndFilter(_ dtos: [StoryDTO]) -> [Story] {
        let now = Date()
        return dtos.compactMap { StoryMapper.toDomain($0) }.filter { $0.expireAt > now }
    }
}
