import Foundation

// Basket lives on the backend (source of truth). Local cache provides instant restore on relaunch.
// Every mutation always writes remote first, then updates the local cache optimistically.
final class BasketRepository: BasketRepositoryProtocol, @unchecked Sendable {
    private let remoteDataSource: BasketRemoteDataSourceProtocol
    private let localDataSource: BasketLocalDataSourceProtocol

    init(
        remoteDataSource: BasketRemoteDataSourceProtocol,
        localDataSource: BasketLocalDataSourceProtocol
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }

    func createBasket(request: CreateBasketRequest) async throws -> Basket {
        let q = request.query
        let apiRequest = CreateBasketAPIRequest(
            userID: q.userID, restaurantID: q.restaurantID, dishID: q.dishID, count: q.count
        )
        let dto = try await remoteDataSource.createBasket(apiRequest)
        localDataSource.saveBasket(dto)
        return BasketMapper.toDomain(dto)
    }

    func updateBasket(request: UpdateBasketRequest) async throws -> Basket {
        let q = request.query
        let apiRequest = UpdateBasketAPIRequest(basketID: q.basketID, dishID: q.dishID, count: q.count)
        let dto = try await remoteDataSource.updateBasket(apiRequest)
        localDataSource.saveBasket(dto)
        return BasketMapper.toDomain(dto)
    }

    func fetchBasket(request: FetchBasketRequest) async throws -> Basket {
        let policy = request.policy
        let basketID = request.path.basketID
        let apiRequest = FetchBasketAPIRequest(basketID: basketID)

        if !policy.force, let cached = localDataSource.fetchBasket(basketID: basketID) {
            return BasketMapper.toDomain(cached)
        }

        let dto = try await remoteDataSource.fetchBasket(apiRequest)
        localDataSource.saveBasket(dto)
        return BasketMapper.toDomain(dto)
    }
}
