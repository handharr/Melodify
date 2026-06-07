import Foundation

// URLSession-based DataSource with no caching. Use in tests and dev previews.
// Swap for ImageDataSource in production coordinators.
public final class URLSessionImageDataSource: ImageDataSourceProtocol {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func load(url: URL) async throws -> Data {
        let (data, _) = try await session.data(from: url)
        return data
    }
}
