import Foundation
@testable import Melodify

final class MockSearchSessionService: SearchSessionServiceProtocol {
    var beginCallCount = 0
    var advanceCallCount = 0
    var lastBeginQuery: String?
    var lastBeginGenre: String?

    var stubbedBeginSession = SearchSession(
        param: SearchTracksParam(query: SearchTracksQuery(term: "", page: 1)),
        policy: .fresh
    )
    var stubbedAdvanceSession = SearchSession(
        param: SearchTracksParam(query: SearchTracksQuery(term: "", page: 2)),
        policy: .cached
    )

    func begin(query: String, genre: String?) -> SearchSession {
        beginCallCount += 1
        lastBeginQuery = query
        lastBeginGenre = genre
        return stubbedBeginSession
    }

    func advance() -> SearchSession {
        advanceCallCount += 1
        return stubbedAdvanceSession
    }
}
