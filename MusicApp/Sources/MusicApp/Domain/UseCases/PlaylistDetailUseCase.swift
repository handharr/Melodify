import Foundation

protocol PlaylistDetailUseCaseProtocol: Sendable {
    func execute(request: PlaylistDetailRequest) async throws -> PlaylistDetail
}

final class PlaylistDetailUseCase: PlaylistDetailUseCaseProtocol, @unchecked Sendable {
    private let playlistRepository: PlaylistRepositoryProtocol
    private let trackRepository: TrackRepositoryProtocol

    init(playlistRepository: PlaylistRepositoryProtocol, trackRepository: TrackRepositoryProtocol) {
        self.playlistRepository = playlistRepository
        self.trackRepository = trackRepository
    }

    func execute(request: PlaylistDetailRequest) async throws -> PlaylistDetail {
        let playlist = try await playlistRepository.fetchPlaylist(id: request.path.playlistId)

        let trackRepo = trackRepository
        let detailRequests = playlist.trackIds.map { GetTrackDetailRequest(path: GetTrackDetailPath(id: $0)) }
        let tracks = try await withThrowingTaskGroup(of: Track.self) { group in
            for r in detailRequests {
                group.addTask { try await trackRepo.getTrackDetail(request: r) }
            }
            var result: [Track] = []
            for try await track in group { result.append(track) }
            return result
        }

        return PlaylistDetail(playlist: playlist, tracks: tracks)
    }
}
