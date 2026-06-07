import Foundation

protocol FetchHomeDataUseCaseProtocol: Sendable {
    func execute(request: FetchHomeDataRequest) async throws -> HomeData
}

final class FetchHomeDataUseCase: FetchHomeDataUseCaseProtocol, @unchecked Sendable {
    private let trackRepository: TrackRepositoryProtocol
    private let playlistRepository: PlaylistRepositoryProtocol

    init(trackRepository: TrackRepositoryProtocol, playlistRepository: PlaylistRepositoryProtocol) {
        self.trackRepository = trackRepository
        self.playlistRepository = playlistRepository
    }

    func execute(request: FetchHomeDataRequest) async throws -> HomeData {
        let trackRequest = SearchTracksRequest(query: request.query.trackQuery, policy: request.policy)
        let trackRepo = trackRepository
        let playlistRepo = playlistRepository
        async let tracks = trackRepo.searchTracks(request: trackRequest)
        async let playlists = playlistRepo.fetchPlaylists()
        return HomeData(featuredTracks: try await tracks, playlists: try await playlists)
    }
}
