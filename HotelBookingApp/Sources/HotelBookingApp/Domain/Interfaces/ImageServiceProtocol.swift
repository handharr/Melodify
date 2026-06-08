import Foundation

protocol ImageServiceProtocol: Sendable {
    func loadImage(url: URL) async throws -> Data
    func loadImages(urls: [URL]) async throws -> [URL: Data]
}
