import Foundation

protocol CreatePlaylistUseCaseProtocol {
    func execute(param: CreatePlaylistParam) async throws -> Playlist
}

final class CreatePlaylistUseCase: CreatePlaylistUseCaseProtocol {
    private let repository: PlaylistRepositoryProtocol

    init(repository: PlaylistRepositoryProtocol) {
        self.repository = repository
    }

    func execute(param: CreatePlaylistParam) async throws -> Playlist {
        guard !param.query.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw PlaylistError.emptyName
        }
        return try await repository.createPlaylist(param: param)
    }
}
