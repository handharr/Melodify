import Foundation

// URLSession-based loader with no caching. Use in tests and dev previews.
// Swap for SDWebImageLoader in production coordinators.
public final class URLSessionImageLoader: ImageLoaderProtocol {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func load(url: URL) async throws -> Data {
        let (data, _) = try await session.data(from: url)
        return data
    }
}
