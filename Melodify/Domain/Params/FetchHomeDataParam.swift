import Foundation

struct FetchHomeDataQuery: Sendable {
    let trackQuery: SearchTracksQuery
}

typealias FetchHomeDataParam = Param<FetchHomeDataQuery, Void>
