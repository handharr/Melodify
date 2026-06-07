import Foundation

protocol TrackRepositoryProtocol: Sendable {
    func searchTracks(policy: FetchPolicy, param: SearchTracksParam) async throws -> [Track]
    func getTrackDetail(policy: FetchPolicy, param: GetTrackDetailParam) async throws -> Track
}
