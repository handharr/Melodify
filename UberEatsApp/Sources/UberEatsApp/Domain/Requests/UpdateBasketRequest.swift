import Foundation
import CoreKit

typealias UpdateBasketRequest = Request<UpdateBasketQuery, Void>

struct UpdateBasketQuery: Sendable, Equatable {
    let basketID: Int
    let dishID: Int
    let count: Int
}
