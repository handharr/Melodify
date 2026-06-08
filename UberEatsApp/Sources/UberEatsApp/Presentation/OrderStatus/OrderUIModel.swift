import Foundation
import CoreLocation

struct OrderUIModel {
    let orderID: Int
    let statusText: String
    let courierLocation: CLLocationCoordinate2D

    static func from(_ order: Order) -> OrderUIModel {
        OrderUIModel(
            orderID: order.orderID,
            statusText: order.status.displayText,
            courierLocation: CLLocationCoordinate2D(
                latitude: order.courierLatitude,
                longitude: order.courierLongitude
            )
        )
    }

    func applying(event: OrderSSEEvent) -> OrderUIModel {
        OrderUIModel(
            orderID: orderID,
            statusText: event.status.displayText,
            courierLocation: CLLocationCoordinate2D(
                latitude: event.courierLatitude,
                longitude: event.courierLongitude
            )
        )
    }
}
