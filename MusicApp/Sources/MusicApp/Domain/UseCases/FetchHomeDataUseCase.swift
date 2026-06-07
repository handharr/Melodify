import Foundation

protocol FetchHomeDataUseCaseProtocol: Sendable {
    func execute(policy: FetchPolicy, param: FetchHomeDataParam) async throws -> HomeData
}

final class FetchHomeDataUseCase: FetchHomeDataUseCaseProtocol, @unchecked Sendable {
    private let trackRepository: TrackRepositoryProtocol
    private let playlistRepository: PlaylistRepositoryProtocol

    init(trackRepository: TrackRepositoryProtocol, playlistRepository: PlaylistRepositoryProtocol) {
        self.trackRepository = trackRepository
        self.playlistRepository = playlistRepository
    }

    func execute(policy: FetchPolicy, param: FetchHomeDataParam) async throws -> HomeData {
        let trackParam = SearchTracksParam(query: param.query.trackQuery)
        let trackRepo = trackRepository
        let playlistRepo = playlistRepository
        async let tracks = trackRepo.searchTracks(policy: policy, param: trackParam)
        async let playlists = playlistRepo.fetchPlaylists()
        return HomeData(featuredTracks: try await tracks, playlists: try await playlists)
    }
}
