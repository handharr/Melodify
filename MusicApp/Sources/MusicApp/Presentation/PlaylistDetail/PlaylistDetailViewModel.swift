import Foundation
import Combine

@MainActor
final class PlaylistDetailViewModel {
    @Published private(set) var detail: PlaylistDetailUIModel?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let playlistId: Int
    private let useCase: PlaylistDetailUseCaseProtocol

    init(playlistId: Int, useCase: PlaylistDetailUseCaseProtocol) {
        self.playlistId = playlistId
        self.useCase = useCase
    }

    func load() {
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let param = PlaylistDetailParam(query: PlaylistDetailQuery(), path: PlaylistDetailPath(playlistId: playlistId))
                let result = try await useCase.execute(policy: .fresh, param: param)
                detail = PlaylistDetailUIModel(
                    name: result.playlist.name,
                    description: result.playlist.description,
                    tracks: result.tracks.map(TrackUIModelMapper.toUIModel)
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
