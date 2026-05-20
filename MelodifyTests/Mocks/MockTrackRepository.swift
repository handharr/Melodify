import Foundation
@testable import Melodify

final class MockTrackRepository: TrackRepositoryProtocol {
    var stubbedResult: Result<[Track], Error> = .success([])
    var callCount = 0
    var receivedParam: SearchTracksParam?

    func searchTracks(policy: FetchPolicy, param: SearchTracksParam) async throws -> [Track] {
        callCount += 1
        receivedParam = param
        return try stubbedResult.get()
    }
}
