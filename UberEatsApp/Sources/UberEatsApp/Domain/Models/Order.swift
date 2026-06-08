import Foundation

struct Order: Sendable {
    let orderID: Int
    let status: OrderStatus
    let basket: Basket
    let courierLatitude: Double
    let courierLongitude: Double
}
