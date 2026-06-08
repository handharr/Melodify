import Foundation

protocol RestaurantLocalDataSourceProtocol: Sendable {
    func fetchRestaurants(addressID: Int) -> [RestaurantDTO]?
    func saveRestaurants(_ dtos: [RestaurantDTO], addressID: Int)
}
