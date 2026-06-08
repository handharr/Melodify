import Foundation
import CoreKit

struct FetchMessagesPath: Sendable, Equatable {
    let conversationId: String
    let beforeMessageId: String?    // cursor — nil loads the latest page
    let limit: Int                  // default 50
}

typealias FetchMessagesRequest = Request<Void, FetchMessagesPath>
