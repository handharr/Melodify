import Foundation

protocol PlaylistRemoteDataSourceProtocol {
    func fetchPlaylists(_ request: FetchPlaylistsAPIRequest) async throws -> [PlaylistDTO]
    func fetchPlaylist(_ request: FetchPlaylistAPIRequest) async throws -> PlaylistDTO
    func createPlaylist(_ request: CreatePlaylistAPIRequest) async throws -> PlaylistDTO
    func updatePlaylist(_ request: UpdatePlaylistAPIRequest) async throws -> PlaylistDTO
}
