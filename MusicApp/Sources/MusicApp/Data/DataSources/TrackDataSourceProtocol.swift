import Foundation

protocol TrackRemoteDataSourceProtocol {
    func searchTracks(_ request: TrackSearchAPIRequest) async throws -> [TrackDTO]
    func getTrackDetail(_ request: TrackDetailAPIRequest) async throws -> TrackDTO
}
