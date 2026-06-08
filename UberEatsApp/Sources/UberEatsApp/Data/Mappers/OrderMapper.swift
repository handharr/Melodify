import Foundation

enum OrderMapper {
    static func toDomain(_ dto: OrderDTO) -> Order? {
        guard let status = OrderStatus(rawValue: dto.status) else { return nil }
        return Order(
            orderID: dto.orderID,
            status: status,
            basket: BasketMapper.toDomain(dto.basket),
            courierLatitude: dto.courierLatitude,
            courierLongitude: dto.courierLongitude
        )
    }

    static func toSSEEvent(_ dto: OrderSSEEventDTO) -> OrderSSEEvent? {
        guard let status = OrderStatus(rawValue: dto.status) else { return nil }
        return OrderSSEEvent(
            orderID: dto.orderID,
            status: status,
            courierLatitude: dto.courierLatitude,
            courierLongitude: dto.courierLongitude
        )
    }
}
