import Foundation

protocol FetchRestaurantsUseCaseProtocol: Sendable {
    func execute(request: FetchRestaurantsRequest) async throws -> [Restaurant]
}

final class FetchRestaurantsUseCase: FetchRestaurantsUseCaseProtocol, @unchecked Sendable {
    private let repository: RestaurantRepositoryProtocol

    init(repository: RestaurantRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: FetchRestaurantsRequest) async throws -> [Restaurant] {
        try await repository.fetchRestaurants(request: request)
    }
}
