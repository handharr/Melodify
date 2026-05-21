import Foundation

protocol PlaylistDetailUseCaseProtocol {
    func execute(policy: FetchPolicy, param: PlaylistDetailParam) async throws -> PlaylistDetail
}

final class PlaylistDetailUseCase: PlaylistDetailUseCaseProtocol {
    private let playlistRepository: PlaylistRepositoryProtocol
    private let trackRepository: TrackRepositoryProtocol

    init(playlistRepository: PlaylistRepositoryProtocol, trackRepository: TrackRepositoryProtocol) {
        self.playlistRepository = playlistRepository
        self.trackRepository = trackRepository
    }

    func execute(policy: FetchPolicy, param: PlaylistDetailParam) async throws -> PlaylistDetail {
        let playlist = try await playlistRepository.fetchPlaylist(id: param.path.playlistId, policy: policy)

        let trackRepo = trackRepository
        let detailParams = playlist.trackIds.map { GetTrackDetailParam(path: GetTrackDetailPath(id: $0)) }
        let tracks = try await withThrowingTaskGroup(of: Track.self) { group in
            for param in detailParams {
                group.addTask {
                    return try await trackRepo.getTrackDetail(policy: .fresh, param: param)
                }
            }
            var result: [Track] = []
            for try await track in group { result.append(track) }
            return result
        }

        return PlaylistDetail(playlist: playlist, tracks: tracks)
    }
}
