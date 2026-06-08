import Foundation

enum OrderStatus: String, Sendable {
    case placed
    case preparing
    case pickedUp
    case inTransit
    case delivered
    case cancelled

    var displayText: String {
        switch self {
        case .placed:     return "Order placed"
        case .preparing:  return "Preparing your order"
        case .pickedUp:   return "Courier picked up"
        case .inTransit:  return "On the way"
        case .delivered:  return "Delivered"
        case .cancelled:  return "Cancelled"
        }
    }
}
