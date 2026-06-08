import Foundation
import CoreKit

final class RestaurantRemoteDataSource: RestaurantRemoteDataSourceProtocol {
    private let client: APIClientProtocol

    init(client: APIClientProtocol) {
        self.client = client
    }

    func fetchRestaurants(_ request: FetchRestaurantsAPIRequest) async throws -> [RestaurantDTO] {
        guard let url = request.url else { throw APIError.invalidURL }
        return try await client.get(url)
    }
}
