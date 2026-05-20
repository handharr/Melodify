import Foundation

protocol UpdatePlaylistUseCaseProtocol {
    func execute(param: UpdatePlaylistParam) async throws -> Playlist
}

final class UpdatePlaylistUseCase: UpdatePlaylistUseCaseProtocol {
    private let repository: PlaylistRepositoryProtocol

    init(repository: PlaylistRepositoryProtocol) {
        self.repository = repository
    }

    func execute(param: UpdatePlaylistParam) async throws -> Playlist {
        guard !param.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw PlaylistError.emptyName
        }
        return try await repository.updatePlaylist(param: param)
    }
}
