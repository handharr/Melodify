import Foundation

public protocol ImageDataSourceProtocol: Sendable {
    func load(url: URL) async throws -> Data
}
