import Foundation

final class PlaylistRepository: PlaylistRepositoryProtocol {
    private let remoteDataSource: PlaylistDataSourceProtocol

    init(remoteDataSource: PlaylistDataSourceProtocol = PlaylistRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
    }

    func fetchPlaylists() async throws -> [Playlist] {
        let dtos = try await remoteDataSource.fetchPlaylists()
        return dtos.map { PlaylistMapper.toDomain($0) }
    }

    func createPlaylist(param: CreatePlaylistParam) async throws -> Playlist {
        let body = CreatePlaylistRequestDTO(
            name: param.query.name,
            description: param.query.description,
            trackIds: param.query.trackIds
        )
        let dto = try await remoteDataSource.createPlaylist(body: body)
        return PlaylistMapper.toDomain(dto)
    }

    func updatePlaylist(param: UpdatePlaylistParam) async throws -> Playlist {
        let body = UpdatePlaylistRequestDTO(
            name: param.query.name,
            description: param.query.description
        )
        let dto = try await remoteDataSource.updatePlaylist(id: param.path.id, body: body)
        return PlaylistMapper.toDomain(dto)
    }
}
