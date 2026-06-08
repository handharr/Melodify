import Foundation
import CoreKit

typealias FetchBasketRequest = Request<Void, FetchBasketPath>

struct FetchBasketPath: Sendable, Equatable {
    let basketID: Int
}
