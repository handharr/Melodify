import Foundation
import CoreKit

struct FetchStoriesQuery: Sendable, Equatable {
    let cursor: Int?
}

typealias FetchStoriesRequest = Request<FetchStoriesQuery, Void>
