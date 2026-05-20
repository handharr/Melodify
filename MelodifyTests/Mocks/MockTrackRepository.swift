import Foundation
@testable import Melodify

final class MockTrackRepository: TrackRepositoryProtocol {
    var stubbedResult: Result<[Track], Error> = .success([])
    var getTrackDetailStubbedResult: Result<Track, Error> = .success(Track(id: 0, title: "", artist: "", album: "", artworkURL: nil, previewURL: nil, genre: "", durationMs: 0))
    
    var callCount = 0
    var getTrackDetailCallCount = 0
    
    var receivedParam: SearchTracksParam?
    var getTrackDetailPolicy: FetchPolicy?
    var getTrackDetailParam: GetTrackDetailParam?

    func searchTracks(policy: FetchPolicy, param: SearchTracksParam) async throws -> [Track] {
        callCount += 1
        receivedParam = param
        return try stubbedResult.get()
    }
    
    func getTrackDetail(policy: FetchPolicy, param: GetTrackDetailParam) async throws -> Track {
        callCount += 1
        getTrackDetailPolicy = policy
        getTrackDetailParam = param
        return try getTrackDetailStubbedResult.get()
    }
}
