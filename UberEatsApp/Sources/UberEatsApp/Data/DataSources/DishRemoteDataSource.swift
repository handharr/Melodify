import Foundation
import CoreKit

final class DishRemoteDataSource: DishRemoteDataSourceProtocol {
    private let client: APIClientProtocol

    init(client: APIClientProtocol) {
        self.client = client
    }

    func fetchDishes(_ request: FetchDishesAPIRequest) async throws -> [DishDTO] {
        guard let url = request.url else { throw APIError.invalidURL }
        return try await client.get(url)
    }
}
