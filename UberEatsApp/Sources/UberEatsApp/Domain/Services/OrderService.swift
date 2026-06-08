import Foundation
import Combine

// Stateful Domain Service — scoped to OrderCoordinator (not app-scoped).
// Opens one SSE connection per tracking session; closes immediately on stopTracking().
final class OrderService: @unchecked Sendable {
    private let sseDataSource: OrderSSEDataSourceProtocol
    private var streamTask: Task<Void, Never>?
    private let subject = PassthroughSubject<OrderSSEEvent, Never>()

    var orderUpdates: AnyPublisher<OrderSSEEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    init(sseDataSource: OrderSSEDataSourceProtocol) {
        self.sseDataSource = sseDataSource
    }

    func startTracking(orderID: Int) {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            let stream = sseDataSource.stream(orderID: orderID)
            for await event in stream {
                guard !Task.isCancelled else { break }
                subject.send(event)
            }
        }
    }

    func stopTracking() {
        streamTask?.cancel()
        streamTask = nil
    }
}
