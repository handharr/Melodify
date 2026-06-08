import Foundation

// Lives in Domain so OrderService (Domain Service) can depend on it without a layer violation.
// The concrete OrderSSEDataSource in Data implements this protocol.
protocol OrderSSEDataSourceProtocol: Sendable {
    func stream(orderID: Int) -> AsyncStream<OrderSSEEvent>
}
