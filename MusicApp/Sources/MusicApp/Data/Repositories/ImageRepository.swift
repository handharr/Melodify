import Foundation
import CoreKit

final class ImageRepository: ImageRepositoryProtocol {
    private let dataSource: ImageDataSourceProtocol
    private let prefetcher: ImagePrefetcherProtocol

    init(dataSource: ImageDataSourceProtocol, prefetcher: ImagePrefetcherProtocol) {
        self.dataSource = dataSource
        self.prefetcher = prefetcher
    }

    func load(url: URL) async throws -> Data {
        try await dataSource.load(url: url)
    }

    func prefetch(urls: [URL]) {
        prefetcher.prefetch(urls: urls)
    }

    func cancelPrefetching(urls: [URL]) {
        prefetcher.cancelPrefetching(urls: urls)
    }
}
