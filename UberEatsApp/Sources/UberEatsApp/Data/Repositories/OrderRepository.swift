import Foundation

final class OrderRepository: OrderRepositoryProtocol, @unchecked Sendable {
    private let remoteDataSource: OrderRemoteDataSourceProtocol

    init(remoteDataSource: OrderRemoteDataSourceProtocol) {
        self.remoteDataSource = remoteDataSource
    }

    func createOrder(request: CreateOrderRequest) async throws -> Order {
        let q = request.query
        let apiRequest = CreateOrderAPIRequest(
            userID: q.userID,
            basketID: q.basketID,
            idempotencyKey: q.idempotencyKey.uuidString
        )
        let dto = try await remoteDataSource.createOrder(apiRequest)
        guard let order = OrderMapper.toDomain(dto) else { throw UberEatsError.notFound }
        return order
    }
}
