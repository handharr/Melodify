import Foundation

protocol OrderRemoteDataSourceProtocol: Sendable {
    func createOrder(_ request: CreateOrderAPIRequest) async throws -> OrderDTO
}
