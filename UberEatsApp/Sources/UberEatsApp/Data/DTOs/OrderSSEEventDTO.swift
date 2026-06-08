import Foundation

struct OrderSSEEventDTO: Codable, Sendable {
    let orderID: Int
    let status: String
    let courierLatitude: Double
    let courierLongitude: Double
}
