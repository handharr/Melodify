import Foundation

final class TrackRemoteDataSource: TrackRemoteDataSourceProtocol {
    private let client: APIClientProtocol
    private let baseURL = "https://itunes.apple.com"

    init(client: APIClientProtocol = APIClient()) {
        self.client = client
    }

    func searchTracks(_ request: TrackSearchRequest) async throws -> [TrackDTO] {
        var components = URLComponents(string: "\(baseURL)/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: request.query),
            URLQueryItem(name: "media", value: request.mediaType),
            URLQueryItem(name: "limit", value: "\(request.limit)"),
            URLQueryItem(name: "offset", value: "\(request.offset)")
        ]
        guard let url = components?.url else { throw APIError.invalidURL }
        let response: iTunesSearchResponse = try await client.get(url)
        return response.results
    }

    func getTrackDetail(_ request: TrackDetailRequest) async throws -> TrackDTO {
        var components = URLComponents(string: "\(baseURL)/lookup")
        components?.queryItems = [
            URLQueryItem(name: "id", value: "\(request.id)")
        ]
        guard let url = components?.url else { throw APIError.invalidURL }
        let response: iTunesSearchResponse = try await client.get(url)
        guard let dto = response.results.first else { throw APIError.notFound }
        return dto
    }
}
