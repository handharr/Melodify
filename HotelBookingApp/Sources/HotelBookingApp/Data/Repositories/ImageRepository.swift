import Foundation
import CoreKit

final class ImageRepository: ImageRepositoryProtocol, @unchecked Sendable {

    private let diskDataSource: ImageDiskDataSourceProtocol
    private let localDataSource: ImageLocalDataSourceProtocol
    private let client: APIClientProtocol

    init(
        diskDataSource: ImageDiskDataSourceProtocol,
        localDataSource: ImageLocalDataSourceProtocol,
        client: APIClientProtocol
    ) {
        self.diskDataSource = diskDataSource
        self.localDataSource = localDataSource
        self.client = client
    }

    // MARK: - ImageRepositoryProtocol

    func loadImage(url: URL) async throws -> Data {
        // 1. Disk cache hit
        if let cached = diskDataSource.loadImage(for: url) {
            return cached
        }

        // 2. Fetch from network — images are raw bytes, not Decodable JSON
        let (data, _) = try await URLSession.shared.data(from: url)

        // 3. Persist to disk
        diskDataSource.saveImage(data, for: url)

        // 4. Record metadata
        let metadata = ImageMetadata(
            url: url,
            filePath: diskDataSource.filePath(for: url),
            savedAt: Date()
        )
        localDataSource.saveMetadata(metadata)

        return data
    }
}
