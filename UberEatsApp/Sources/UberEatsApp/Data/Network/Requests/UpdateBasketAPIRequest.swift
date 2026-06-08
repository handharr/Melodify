import Foundation

struct UpdateBasketAPIRequest: Encodable, Sendable {
    let basketID: Int
    let dishID: Int
    let count: Int
    static let url = URL(string: "https://api.ubereats-mock.com/v1/basket")!
}
