import Foundation

typealias FetchRestaurantsRequest = Request<Void, FetchRestaurantsPath>

struct FetchRestaurantsPath: Sendable, Equatable {
    let addressID: Int
}
