import Foundation

struct MarkReadPath: Sendable, Equatable {
    let conversationId: String
}

typealias MarkReadRequest = Request<Void, MarkReadPath>
