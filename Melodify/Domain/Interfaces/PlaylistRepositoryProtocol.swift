import Foundation

protocol PlaylistRepositoryProtocol {
    func fetchPlaylists() async throws -> [Playlist]
    func fetchPlaylist(id: Int) async throws -> Playlist
    func createPlaylist(param: CreatePlaylistParam) async throws -> Playlist
    func updatePlaylist(param: UpdatePlaylistParam) async throws -> Playlist
}
