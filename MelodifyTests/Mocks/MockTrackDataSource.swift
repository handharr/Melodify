import Foundation
@testable import Melodify

final class MockTrackDataSource: TrackRemoteDataSourceProtocol {
    var searchResult: Result<[TrackDTO], Error> = .success([])
    var detailResult: Result<TrackDTO, Error> = .success(.stub())

    private(set) var lastSearchRequest: TrackSearchRequest?
    private(set) var lastDetailRequest: TrackDetailRequest?

    func searchTracks(_ request: TrackSearchRequest) async throws -> [TrackDTO] {
        lastSearchRequest = request
        return try searchResult.get()
    }

    func getTrackDetail(_ request: TrackDetailRequest) async throws -> TrackDTO {
        lastDetailRequest = request
        return try detailResult.get()
    }
}
