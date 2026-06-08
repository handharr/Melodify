import Foundation

enum UberEatsError: Error, Sendable {
    case notFound
    case networkError(Error)
    case decodingFailed
    case basketConflict
    case sseDisconnected
}
