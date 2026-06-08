import Foundation

struct Basket: Sendable {
    let basketID: Int
    let userID: Int
    let restaurantID: Int
    let selectedDishes: [(dishID: Int, count: Int)]
}
