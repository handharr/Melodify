import Foundation

protocol RestaurantRemoteDataSourceProtocol: Sendable {
    func fetchRestaurants(_ request: FetchRestaurantsAPIRequest) async throws -> [RestaurantDTO]
}
