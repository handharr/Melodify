import Foundation

struct OrderSSEEvent: Sendable {
    let orderID: Int
    let status: OrderStatus
    let courierLatitude: Double
    let courierLongitude: Double
}
