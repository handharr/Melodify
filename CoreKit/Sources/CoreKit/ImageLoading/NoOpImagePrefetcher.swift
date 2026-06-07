import Foundation

public final class NoOpImagePrefetcher: ImagePrefetcherProtocol {
    public init() {}

    public func prefetch(urls: [URL]) {}
    public func cancelPrefetching(urls: [URL]) {}
}
