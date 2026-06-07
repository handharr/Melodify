import Foundation

protocol UpdatePlaylistUseCaseProtocol {
    func execute(request: UpdatePlaylistRequest) async throws -> Playlist
}

final class UpdatePlaylistUseCase: UpdatePlaylistUseCaseProtocol {
    private let repository: PlaylistRepositoryProtocol

    init(repository: PlaylistRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: UpdatePlaylistRequest) async throws -> Playlist {
        guard !request.query.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw PlaylistError.emptyName
        }
        return try await repository.updatePlaylist(request: request)
    }
}
