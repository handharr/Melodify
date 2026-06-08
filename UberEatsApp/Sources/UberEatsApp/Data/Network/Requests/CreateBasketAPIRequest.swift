import Foundation

struct CreateBasketAPIRequest: Encodable, Sendable {
    let userID: Int
    let restaurantID: Int
    let dishID: Int
    let count: Int
    static let url = URL(string: "https://api.ubereats-mock.com/v1/basket")!
}
