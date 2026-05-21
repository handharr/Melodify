import Foundation

final class PlaylistRepository: PlaylistRepositoryProtocol {
    private let remoteDataSource: PlaylistDataSourceProtocol

    init(remoteDataSource: PlaylistDataSourceProtocol = PlaylistRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
    }

    func fetchPlaylists(policy: FetchPolicy) async throws -> [Playlist] {
        let dtos = try await remoteDataSource.fetchPlaylists(FetchPlaylistsRequest())
        return dtos.map { PlaylistMapper.toDomain($0) }
    }

    func fetchPlaylist(id: Int, policy: FetchPolicy) async throws -> Playlist {
        let dto = try await remoteDataSource.fetchPlaylist(FetchPlaylistRequest(id: id))
        return PlaylistMapper.toDomain(dto)
    }

    func createPlaylist(param: CreatePlaylistParam) async throws -> Playlist {
        let request = CreatePlaylistRequest(
            name: param.query.name,
            description: param.query.description,
            trackIds: param.query.trackIds
        )
        let dto = try await remoteDataSource.createPlaylist(request)
        return PlaylistMapper.toDomain(dto)
    }

    func updatePlaylist(param: UpdatePlaylistParam) async throws -> Playlist {
        let request = UpdatePlaylistRequest(
            id: param.path.id,
            name: param.query.name,
            description: param.query.description
        )
        let dto = try await remoteDataSource.updatePlaylist(request)
        return PlaylistMapper.toDomain(dto)
    }
}
