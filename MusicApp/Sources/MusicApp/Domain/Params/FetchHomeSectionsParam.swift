import Foundation

struct FetchHomeSectionsQuery: Sendable {
    let genreQueries: [(genre: String, query: SearchTracksQuery)]
}

typealias FetchHomeSectionsParam = Param<FetchHomeSectionsQuery, Void>
