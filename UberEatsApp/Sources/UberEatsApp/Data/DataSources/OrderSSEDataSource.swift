import Foundation

// Concrete implementation of the Domain-owned OrderSSEDataSourceProtocol.
// Maps OrderSSEEventDTO → OrderSSEEvent (Domain) so OrderService receives domain types only.
final class OrderSSEDataSource: OrderSSEDataSourceProtocol {
    private let sseClient: SSEClient

    init(sseClient: SSEClient = SSEClient()) {
        self.sseClient = sseClient
    }

    func stream(orderID: Int) -> AsyncStream<OrderSSEEvent> {
        guard let url = URL(string: "https://api.ubereats-mock.com/v1/live-order-status/\(orderID)") else {
            return AsyncStream { $0.finish() }
        }
        let rawStream = sseClient.stream(url: url, as: OrderSSEEventDTO.self)
        return AsyncStream { continuation in
            let task = Task {
                for await dto in rawStream {
                    guard !Task.isCancelled else { break }
                    if let event = OrderMapper.toSSEEvent(dto) {
                        continuation.yield(event)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
