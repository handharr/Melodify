import Foundation

protocol BasketRepositoryProtocol: Sendable {
    func createBasket(request: CreateBasketRequest) async throws -> Basket
    func updateBasket(request: UpdateBasketRequest) async throws -> Basket
    func fetchBasket(request: FetchBasketRequest) async throws -> Basket
}
