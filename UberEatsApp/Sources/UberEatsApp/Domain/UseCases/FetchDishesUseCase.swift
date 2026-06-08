import Foundation

protocol FetchDishesUseCaseProtocol: Sendable {
    func execute(request: FetchDishesRequest) async throws -> [Dish]
}

final class FetchDishesUseCase: FetchDishesUseCaseProtocol, @unchecked Sendable {
    private let repository: DishRepositoryProtocol

    init(repository: DishRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: FetchDishesRequest) async throws -> [Dish] {
        try await repository.fetchDishes(request: request)
    }
}
