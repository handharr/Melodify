import Foundation
import CoreKit

final class OrderRemoteDataSource: OrderRemoteDataSourceProtocol {
    private let client: APIClientProtocol

    init(client: APIClientProtocol) {
        self.client = client
    }

    func createOrder(_ request: CreateOrderAPIRequest) async throws -> OrderDTO {
        try await client.post(CreateOrderAPIRequest.url, body: request)
    }
}
