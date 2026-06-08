import Foundation

final class DishRepository: DishRepositoryProtocol, @unchecked Sendable {
    private let remoteDataSource: DishRemoteDataSourceProtocol
    private let localDataSource: DishLocalDataSourceProtocol

    init(
        remoteDataSource: DishRemoteDataSourceProtocol,
        localDataSource: DishLocalDataSourceProtocol
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }

    func fetchDishes(request: FetchDishesRequest) async throws -> [Dish] {
        let policy = request.policy
        let restaurantID = request.path.restaurantID
        let apiRequest = FetchDishesAPIRequest(restaurantID: restaurantID)

        if !policy.force && !policy.allowStale {
            guard let cached = localDataSource.fetchDishes(restaurantID: restaurantID) else {
                throw UberEatsError.notFound
            }
            return cached.compactMap(DishMapper.toDomain)
        }

        if !policy.force, let cached = localDataSource.fetchDishes(restaurantID: restaurantID) {
            return cached.compactMap(DishMapper.toDomain)
        }

        let dtos = try await remoteDataSource.fetchDishes(apiRequest)
        localDataSource.saveDishes(dtos, restaurantID: restaurantID)
        return dtos.compactMap(DishMapper.toDomain)
    }
}
