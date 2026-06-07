import Foundation

final class PlaylistRepository: PlaylistRepositoryProtocol, @unchecked Sendable {
    private let remoteDataSource: PlaylistRemoteDataSourceProtocol

    init(remoteDataSource: PlaylistRemoteDataSourceProtocol) {
        self.remoteDataSource = remoteDataSource
    }

    func fetchPlaylists() async throws -> [Playlist] {
        let dtos = try await remoteDataSource.fetchPlaylists(FetchPlaylistsAPIRequest())
        return dtos.map { PlaylistMapper.toDomain($0) }
    }

    func fetchPlaylist(id: Int) async throws -> Playlist {
        let dto = try await remoteDataSource.fetchPlaylist(FetchPlaylistAPIRequest(id: id))
        return PlaylistMapper.toDomain(dto)
    }

    func createPlaylist(request: CreatePlaylistRequest) async throws -> Playlist {
        let apiRequest = CreatePlaylistAPIRequest(
            name: request.query.name,
            description: request.query.description,
            trackIds: request.query.trackIds
        )
        let dto = try await remoteDataSource.createPlaylist(apiRequest)
        return PlaylistMapper.toDomain(dto)
    }

    func updatePlaylist(request: UpdatePlaylistRequest) async throws -> Playlist {
        let apiRequest = UpdatePlaylistAPIRequest(
            id: request.path.id,
            name: request.query.name,
            description: request.query.description
        )
        let dto = try await remoteDataSource.updatePlaylist(apiRequest)
        return PlaylistMapper.toDomain(dto)
    }
}
