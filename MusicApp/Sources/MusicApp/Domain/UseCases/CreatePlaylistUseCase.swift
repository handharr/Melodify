import Foundation

protocol CreatePlaylistUseCaseProtocol {
    func execute(request: CreatePlaylistRequest) async throws -> Playlist
}

final class CreatePlaylistUseCase: CreatePlaylistUseCaseProtocol {
    private let repository: PlaylistRepositoryProtocol

    init(repository: PlaylistRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: CreatePlaylistRequest) async throws -> Playlist {
        guard !request.query.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw PlaylistError.emptyName
        }
        return try await repository.createPlaylist(request: request)
    }
}
