import Foundation

protocol ImageRepositoryProtocol {
    func load(url: URL) async throws -> Data
    func prefetch(urls: [URL])
    func cancelPrefetching(urls: [URL])
}
