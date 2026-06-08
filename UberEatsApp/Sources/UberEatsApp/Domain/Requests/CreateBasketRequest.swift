import Foundation

typealias CreateBasketRequest = Request<CreateBasketQuery, Void>

struct CreateBasketQuery: Sendable, Equatable {
    let userID: Int
    let restaurantID: Int
    let dishID: Int
    let count: Int
}
