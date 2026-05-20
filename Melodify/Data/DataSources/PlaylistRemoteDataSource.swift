import Foundation

final class PlaylistRemoteDataSource: PlaylistDataSourceProtocol {
    private let client: APIClient
    private let baseURL = "https://6a09e642e7e3f433d483900b.mockapi.io/api/v1/playlist"

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    func fetchPlaylists() async throws -> [PlaylistDTO] {
        guard let url = URL(string: baseURL) else { throw APIError.invalidURL }
        return try await client.get(url)
    }

    func createPlaylist(body: CreatePlaylistRequestDTO) async throws -> PlaylistDTO {
        guard let url = URL(string: baseURL) else { throw APIError.invalidURL }
        return try await client.post(url, body: body)
    }

    func updatePlaylist(id: Int, body: UpdatePlaylistRequestDTO) async throws -> PlaylistDTO {
        guard let url = URL(string: "\(baseURL)/\(id)") else { throw APIError.invalidURL }
        return try await client.put(url, body: body)
    }
}
