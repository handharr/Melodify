import Foundation

protocol FetchHomeDataUseCaseProtocol {
    func execute(policy: FetchPolicy, param: FetchHomeDataParam) async throws -> HomeData
}

final class FetchHomeDataUseCase: FetchHomeDataUseCaseProtocol {
    private let trackRepository: TrackRepositoryProtocol
    private let playlistRepository: PlaylistRepositoryProtocol

    init(trackRepository: TrackRepositoryProtocol, playlistRepository: PlaylistRepositoryProtocol) {
        self.trackRepository = trackRepository
        self.playlistRepository = playlistRepository
    }

    func execute(policy: FetchPolicy, param: FetchHomeDataParam) async throws -> HomeData {
        let trackParam = SearchTracksParam(query: param.query.trackQuery)
        async let tracks = trackRepository.searchTracks(policy: policy, param: trackParam)
        async let playlists = playlistRepository.fetchPlaylists()
        return HomeData(featuredTracks: try await tracks, playlists: try await playlists)
    }
}
