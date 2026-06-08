import Foundation

protocol RestaurantRepositoryProtocol: Sendable {
    func fetchRestaurants(request: FetchRestaurantsRequest) async throws -> [Restaurant]
}
