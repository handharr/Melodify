import Foundation
import CoreKit

typealias CreateOrderRequest = Request<CreateOrderQuery, Void>

struct CreateOrderQuery: Sendable {
    let userID: Int
    let basketID: Int
    let idempotencyKey: UUID
}
