import Foundation

struct Dish: Sendable {
    let dishID: Int
    let restaurantID: Int
    let name: String
    let price: Double
    let imageURL: URL
}
