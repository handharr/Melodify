import Foundation

struct FetchMessagesPath: Sendable, Equatable {
    let conversationId: String
}

typealias FetchMessagesRequest = Request<Void, FetchMessagesPath>
