import Foundation

struct OrderDTO: Codable, Sendable {
    let orderID: Int
    let status: String
    let basket: BasketDTO
    let courierLatitude: Double
    let courierLongitude: Double
}
