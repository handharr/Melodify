import Foundation

protocol PlaylistDataSourceProtocol {
    func fetchPlaylists() async throws -> [PlaylistDTO]
    func createPlaylist(body: CreatePlaylistRequestDTO) async throws -> PlaylistDTO
    func updatePlaylist(id: Int, body: UpdatePlaylistRequestDTO) async throws -> PlaylistDTO
}
