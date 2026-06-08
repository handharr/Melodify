import Foundation
import CoreKit

struct MarkReadPath: Sendable, Equatable {
    let conversationId: String
}

typealias MarkReadRequest = Request<Void, MarkReadPath>
