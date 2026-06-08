import Foundation

protocol UpdateBasketUseCaseProtocol: Sendable {
    func execute(request: UpdateBasketRequest) async throws -> Basket
}

final class UpdateBasketUseCase: UpdateBasketUseCaseProtocol, @unchecked Sendable {
    private let repository: BasketRepositoryProtocol

    init(repository: BasketRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: UpdateBasketRequest) async throws -> Basket {
        try await repository.updateBasket(request: request)
    }
}
