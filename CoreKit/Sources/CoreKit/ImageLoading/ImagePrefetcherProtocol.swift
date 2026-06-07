import Foundation

public protocol ImagePrefetcherProtocol: Sendable {
    func prefetch(urls: [URL])
    func cancelPrefetching(urls: [URL])
}
