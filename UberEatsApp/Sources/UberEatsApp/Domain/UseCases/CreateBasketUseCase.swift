import Foundation

protocol CreateBasketUseCaseProtocol: Sendable {
    func execute(request: CreateBasketRequest) async throws -> Basket
}

final class CreateBasketUseCase: CreateBasketUseCaseProtocol, @unchecked Sendable {
    private let repository: BasketRepositoryProtocol

    init(repository: BasketRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: CreateBasketRequest) async throws -> Basket {
        try await repository.createBasket(request: request)
    }
}
