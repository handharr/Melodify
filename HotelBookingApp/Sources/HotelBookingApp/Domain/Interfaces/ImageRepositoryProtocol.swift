import Foundation

protocol ImageRepositoryProtocol: Sendable {
    func loadImage(url: URL) async throws -> Data
}
