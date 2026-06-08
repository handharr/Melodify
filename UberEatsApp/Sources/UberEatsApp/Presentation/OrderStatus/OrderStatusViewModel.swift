import Foundation
import Combine

@MainActor
final class OrderStatusViewModel {
    @Published private(set) var order: OrderUIModel
    private let orderService: OrderService
    private var cancellables = Set<AnyCancellable>()

    init(initialOrder: Order, orderService: OrderService) {
        self.order = OrderUIModel.from(initialOrder)
        self.orderService = orderService
    }

    func startTracking() {
        orderService.orderUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.order = self?.order.applying(event: event) ?? self!.order
            }
            .store(in: &cancellables)

        orderService.startTracking(orderID: order.orderID)
    }

    func stopTracking() {
        orderService.stopTracking()
        cancellables.removeAll()
    }
}
