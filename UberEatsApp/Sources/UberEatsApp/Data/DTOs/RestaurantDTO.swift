import Foundation

struct RestaurantDTO: Codable, Sendable {
    let restaurantID: Int
    let name: String
    let rating: Int
    let address: AddressDTO
    let imageURL: String
}
