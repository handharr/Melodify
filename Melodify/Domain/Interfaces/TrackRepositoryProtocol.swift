import Foundation

protocol TrackRepositoryProtocol {
    func searchTracks(policy: FetchPolicy, param: SearchTracksParam) async throws -> [Track]
    func getTrackDetail(policy: FetchPolicy, param: GetTrackDetailParam) async throws -> Track
}
