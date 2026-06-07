import Foundation

protocol TrackRemoteDataSourceProtocol {
    func searchTracks(_ request: TrackSearchRequest) async throws -> [TrackDTO]
    func getTrackDetail(_ request: TrackDetailRequest) async throws -> TrackDTO
}
