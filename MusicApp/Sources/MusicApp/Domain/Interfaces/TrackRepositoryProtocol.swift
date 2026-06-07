import Foundation

protocol TrackRepositoryProtocol: Sendable {
    func searchTracks(request: SearchTracksRequest) async throws -> [Track]
    func getTrackDetail(request: GetTrackDetailRequest) async throws -> Track
}
