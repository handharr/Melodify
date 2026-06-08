import Foundation

typealias FetchDishesRequest = Request<Void, FetchDishesPath>

struct FetchDishesPath: Sendable, Equatable {
    let restaurantID: Int
}
