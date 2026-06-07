import Foundation

struct SearchTracksQuery: Sendable, Equatable {
    let term: String
    let page: Int
    let limit: Int
    var genre: String?

    var offset: Int { (page - 1) * limit }

    init(term: String, page: Int = 1, limit: Int = 20, genre: String? = nil) {
        self.term = term
        self.page = page
        self.limit = limit
        self.genre = genre
    }
}

typealias SearchTracksParam = Param<SearchTracksQuery, Void>
