import Foundation

struct FetchHomeDataQuery: Sendable {
    let trackQuery: SearchTracksQuery
}

typealias FetchHomeDataRequest = Request<FetchHomeDataQuery, Void>
