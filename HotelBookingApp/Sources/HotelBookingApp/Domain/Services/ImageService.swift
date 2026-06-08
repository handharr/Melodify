import Foundation

final class ImageService: ImageServiceProtocol, @unchecked Sendable {
    private let imageRepository: ImageRepositoryProtocol

    init(imageRepository: ImageRepositoryProtocol) {
        self.imageRepository = imageRepository
    }

    func loadImage(url: URL) async throws -> Data {
        try await imageRepository.loadImage(url: url)
    }

    func loadImages(urls: [URL]) async throws -> [URL: Data] {
        try await withThrowingTaskGroup(of: (URL, Data).self) { group in
            for url in urls {
                group.addTask { [weak self] in
                    guard let self else { throw CancellationError() }
                    let data = try await self.imageRepository.loadImage(url: url)
                    return (url, data)
                }
            }
            var result: [URL: Data] = [:]
            for try await (url, data) in group {
                result[url] = data
            }
            return result
        }
    }
}
