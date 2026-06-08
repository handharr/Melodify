import Foundation

struct CreateOrderAPIRequest: Encodable, Sendable {
    let userID: Int
    let basketID: Int
    let idempotencyKey: String
    static let url = URL(string: "https://api.ubereats-mock.com/v1/orders")!
}
