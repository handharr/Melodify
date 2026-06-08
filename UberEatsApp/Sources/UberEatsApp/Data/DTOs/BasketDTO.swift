import Foundation

struct BasketDTO: Codable, Sendable {
    let basketID: Int
    let userID: Int
    let restaurantID: Int
    let selectedDishes: [BasketItemDTO]
}

struct BasketItemDTO: Codable, Sendable {
    let dishID: Int
    let count: Int
}
