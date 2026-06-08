import Foundation
import CoreKit

final class BasketRemoteDataSource: BasketRemoteDataSourceProtocol {
    private let client: APIClientProtocol

    init(client: APIClientProtocol) {
        self.client = client
    }

    func createBasket(_ request: CreateBasketAPIRequest) async throws -> BasketDTO {
        try await client.post(CreateBasketAPIRequest.url, body: request)
    }

    func updateBasket(_ request: UpdateBasketAPIRequest) async throws -> BasketDTO {
        try await client.patch(UpdateBasketAPIRequest.url, body: request)
    }

    func fetchBasket(_ request: FetchBasketAPIRequest) async throws -> BasketDTO {
        guard let url = request.url else { throw APIError.invalidURL }
        return try await client.get(url)
    }
}
