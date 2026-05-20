import Foundation

protocol TrackRepositoryProtocol {
    func searchTracks(policy: FetchPolicy, param: SearchTracksParam) async throws -> [Track]
}
