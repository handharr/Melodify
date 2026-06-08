import Foundation

protocol OrderRepositoryProtocol: Sendable {
    func createOrder(request: CreateOrderRequest) async throws -> Order
}
