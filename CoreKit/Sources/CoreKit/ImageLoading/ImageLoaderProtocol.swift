import Foundation

public protocol ImageLoaderProtocol: Sendable {
    func load(url: URL) async throws -> Data
}
