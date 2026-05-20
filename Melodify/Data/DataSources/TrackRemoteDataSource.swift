import Foundation

final class TrackRemoteDataSource: TrackDataSourceProtocol {
    private let client: APIClient
    private let baseURL = "https://itunes.apple.com/search"

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    func searchTracks(query: String, offset: Int, limit: Int) async throws -> [TrackDTO] {
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        guard let url = components?.url else { throw APIError.invalidURL }
        let response: iTunesSearchResponse = try await client.get(url)
        return response.results
    }
}
