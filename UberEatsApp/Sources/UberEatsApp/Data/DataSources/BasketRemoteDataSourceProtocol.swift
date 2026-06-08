import Foundation

protocol BasketRemoteDataSourceProtocol: Sendable {
    func createBasket(_ request: CreateBasketAPIRequest) async throws -> BasketDTO
    func updateBasket(_ request: UpdateBasketAPIRequest) async throws -> BasketDTO
    func fetchBasket(_ request: FetchBasketAPIRequest) async throws -> BasketDTO
}
