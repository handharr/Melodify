import UIKit

// URLSession + NSCache implementation — stores decoded UIImage objects directly.
// NSURLCache stores raw bytes; every display would require bytes → UIImage decode on main thread.
// NSCache<NSURL, UIImage> is thread-safe; no additional locking needed.
// NSCache is thread-safe, so @unchecked Sendable is safe here.
final class StoryImageDataSource: StoryImageDataSourceProtocol, @unchecked Sendable {
    private let session: URLSession
    private let cache = NSCache<NSURL, UIImage>()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func loadImage(url: URL) async throws -> UIImage {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        let (data, _) = try await session.data(from: url)
        guard let image = UIImage(data: data) else {
            throw StoryError.imageDecodingFailed
        }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    func prefetch(url: URL) {
        Task { [weak self] in try? await self?.loadImage(url: url) }
    }
}
