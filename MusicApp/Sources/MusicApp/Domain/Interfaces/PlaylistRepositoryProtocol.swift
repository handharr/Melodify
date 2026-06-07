import Foundation

protocol PlaylistRepositoryProtocol: Sendable {
    func fetchPlaylists() async throws -> [Playlist]
    func fetchPlaylist(id: Int) async throws -> Playlist
    func createPlaylist(request: CreatePlaylistRequest) async throws -> Playlist
    func updatePlaylist(request: UpdatePlaylistRequest) async throws -> Playlist
}
