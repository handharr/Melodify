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
            name: param.name,
            description: param.description,
            trackIds: param.trackIds
        )
        let dto = try await remoteDataSource.createPlaylist(body: body)
        return PlaylistMapper.toDomain(dto)
    }

    func updatePlaylist(param: UpdatePlaylistParam) async throws -> Playlist {
        let body = UpdatePlaylistRequestDTO(
            name: param.name,
            description: param.description
        )
        let dto = try await remoteDataSource.updatePlaylist(id: param.id, body: body)
        return PlaylistMapper.toDomain(dto)
    }
}
