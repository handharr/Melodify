import Foundation
import CoreKit

typealias FetchRestaurantsRequest = Request<Void, FetchRestaurantsPath>

struct FetchRestaurantsPath: Sendable, Equatable {
    let addressID: Int
}
