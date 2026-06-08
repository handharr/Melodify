import Foundation
import CoreKit

struct FetchHomeSectionsQuery: Sendable {
    let genreQueries: [(genre: String, query: SearchTracksQuery)]
}

typealias FetchHomeSectionsRequest = Request<FetchHomeSectionsQuery, Void>
