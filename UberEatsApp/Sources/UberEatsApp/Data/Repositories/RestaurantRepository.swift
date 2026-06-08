import Foundation

final class RestaurantRepository: RestaurantRepositoryProtocol, @unchecked Sendable {
    private let remoteDataSource: RestaurantRemoteDataSourceProtocol
    private let localDataSource: RestaurantLocalDataSourceProtocol

    init(
        remoteDataSource: RestaurantRemoteDataSourceProtocol,
        localDataSource: RestaurantLocalDataSourceProtocol
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }

    func fetchRestaurants(request: FetchRestaurantsRequest) async throws -> [Restaurant] {
        let policy = request.policy
        let addressID = request.path.addressID
        let apiRequest = FetchRestaurantsAPIRequest(addressID: addressID)

        if !policy.force && !policy.allowStale {
            guard let cached = localDataSource.fetchRestaurants(addressID: addressID) else {
                throw UberEatsError.notFound
            }
            return cached.compactMap(RestaurantMapper.toDomain)
        }

        if !policy.force, let cached = localDataSource.fetchRestaurants(addressID: addressID) {
            return cached.compactMap(RestaurantMapper.toDomain)
        }

        let dtos = try await remoteDataSource.fetchRestaurants(apiRequest)
        localDataSource.saveRestaurants(dtos, addressID: addressID)
        return dtos.compactMap(RestaurantMapper.toDomain)
    }
}
