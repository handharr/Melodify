import Foundation

protocol PlaylistDataSourceProtocol {
    func fetchPlaylists(_ request: FetchPlaylistsRequest) async throws -> [PlaylistDTO]
    func fetchPlaylist(_ request: FetchPlaylistRequest) async throws -> PlaylistDTO
    func createPlaylist(_ request: CreatePlaylistRequest) async throws -> PlaylistDTO
    func updatePlaylist(_ request: UpdatePlaylistRequest) async throws -> PlaylistDTO
}
