import Foundation

protocol CreateOrderUseCaseProtocol: Sendable {
    func execute(request: CreateOrderRequest) async throws -> Order
}

final class CreateOrderUseCase: CreateOrderUseCaseProtocol, @unchecked Sendable {
    private let repository: OrderRepositoryProtocol

    init(repository: OrderRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: CreateOrderRequest) async throws -> Order {
        try await repository.createOrder(request: request)
    }
}
