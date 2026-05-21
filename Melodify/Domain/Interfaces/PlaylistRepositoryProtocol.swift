import Foundation

protocol PlaylistRepositoryProtocol {
    func fetchPlaylists(policy: FetchPolicy) async throws -> [Playlist]
    func fetchPlaylist(id: Int, policy: FetchPolicy) async throws -> Playlist
    func createPlaylist(param: CreatePlaylistParam) async throws -> Playlist
    func updatePlaylist(param: UpdatePlaylistParam) async throws -> Playlist
}
