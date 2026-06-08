import Foundation
import CoreKit

struct FetchConversationsQuery: Sendable, Equatable {
    let userId: String
}

typealias FetchConversationsRequest = Request<FetchConversationsQuery, Void>
