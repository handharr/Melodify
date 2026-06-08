import Foundation

protocol FetchBasketUseCaseProtocol: Sendable {
    func execute(request: FetchBasketRequest) async throws -> Basket
}

final class FetchBasketUseCase: FetchBasketUseCaseProtocol, @unchecked Sendable {
    private let repository: BasketRepositoryProtocol

    init(repository: BasketRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: FetchBasketRequest) async throws -> Basket {
        try await repository.fetchBasket(request: request)
    }
}
