import Foundation
@testable import Melodify

final class MockTrackLocalDataSource: TrackLocalDataSourceProtocol {
    var searchResult: [TrackDTO]? = nil
    var detailResult: TrackDTO? = nil

    private(set) var savedSearchTracks: [TrackDTO]?
    private(set) var savedDetailTrack: TrackDTO?
    private(set) var lastSearchRequest: TrackSearchRequest?
    private(set) var lastDetailRequest: TrackDetailRequest?

    func searchTracks(request: TrackSearchRequest) -> [TrackDTO]? {
        lastSearchRequest = request
        return searchResult
    }

    func saveSearchTracks(_ tracks: [TrackDTO], for request: TrackSearchRequest) {
        savedSearchTracks = tracks
    }

    func getTrackDetail(request: TrackDetailRequest) -> TrackDTO? {
        lastDetailRequest = request
        return detailResult
    }

    func saveTrackDetail(_ track: TrackDTO, for request: TrackDetailRequest) {
        savedDetailTrack = track
    }
}
