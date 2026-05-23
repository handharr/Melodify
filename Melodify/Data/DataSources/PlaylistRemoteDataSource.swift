import Foundation

final class PlaylistRemoteDataSource: PlaylistRemoteDataSourceProtocol {
    private let client: APIClientProtocol
    private let baseURL = "https://6a09e642e7e3f433d483900b.mockapi.io/api/v1/playlist"

    init(client: APIClientProtocol = APIClient()) {
        self.client = client
    }

    func fetchPlaylists(_ request: FetchPlaylistsRequest) async throws -> [PlaylistDTO] {
        guard let url = URL(string: baseURL) else { throw APIError.invalidURL }
        return try await client.get(url)
    }

    func fetchPlaylist(_ request: FetchPlaylistRequest) async throws -> PlaylistDTO {
        guard let url = URL(string: "\(baseURL)/\(request.id)") else { throw APIError.invalidURL }
        return try await client.get(url)
    }

    func createPlaylist(_ request: CreatePlaylistRequest) async throws -> PlaylistDTO {
        guard let url = URL(string: baseURL) else { throw APIError.invalidURL }
        return try await client.post(url, body: request)
    }

    func updatePlaylist(_ request: UpdatePlaylistRequest) async throws -> PlaylistDTO {
        guard let url = URL(string: "\(baseURL)/\(request.id)") else { throw APIError.invalidURL }
        return try await client.put(url, body: request)
    }
}
