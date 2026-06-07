import Foundation

enum ChatError: Error, Sendable {
    case messageQueued       // send failed, message saved to offline queue
    case sendFailed(Error)
    case notConnected
    case decodingFailed
}
