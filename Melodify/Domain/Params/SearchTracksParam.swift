import Foundation

struct SearchTracksParam: Sendable {
    let query: String
    let page: Int
    let limit: Int
    let genre: String?

    var offset: Int { (page - 1) * limit }

    nonisolated init(query: String, page: Int = 1, limit: Int = 20, genre: String? = nil) {
        self.query = query
        self.page = page
        self.limit = limit
        self.genre = genre
    }
}
