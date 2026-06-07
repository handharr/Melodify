import Foundation

struct SearchSession {
    let param: SearchTracksParam
    let policy: FetchPolicy
}

protocol SearchSessionServiceProtocol: Sendable {
    func begin(query: String, genre: String?) -> SearchSession
    func advance() -> SearchSession
}

final class SearchSessionService: SearchSessionServiceProtocol, @unchecked Sendable {
    private let limit: Int
    private var currentQuery: String = ""
    private var currentPage: Int = 1
    private var currentGenre: String?

    init(limit: Int = 20) {
        self.limit = limit
    }

    func begin(query: String, genre: String? = nil) -> SearchSession {
        currentQuery = query
        currentPage = 1
        currentGenre = genre
        return build(policy: .fresh)
    }

    func advance() -> SearchSession {
        currentPage += 1
        return build(policy: .cached)
    }

    private func build(policy: FetchPolicy) -> SearchSession {
        SearchSession(
            param: SearchTracksParam(
                query: SearchTracksQuery(
                    term: currentQuery,
                    page: currentPage,
                    limit: limit,
                    genre: currentGenre
                )
            ),
            policy: policy
        )
    }
}
