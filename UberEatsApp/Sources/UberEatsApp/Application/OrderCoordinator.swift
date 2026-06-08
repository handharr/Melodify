import UIKit

// Scoped to the order tracking flow — created when an order is placed, deallocated when the
// user exits the Order Status screen. OrderService lifetime matches this coordinator.
@MainActor
final class OrderCoordinator {
    private let navigationController: UINavigationController
    private let orderService: OrderService
    private let basketRepository: BasketRepositoryProtocol
    private let dishRepository: DishRepositoryProtocol
    private let orderRepository: OrderRepositoryProtocol

    init(
        navigationController: UINavigationController,
        orderService: OrderService,
        basketRepository: BasketRepositoryProtocol,
        dishRepository: DishRepositoryProtocol,
        orderRepository: OrderRepositoryProtocol
    ) {
        self.navigationController = navigationController
        self.orderService = orderService
        self.basketRepository = basketRepository
        self.dishRepository = dishRepository
        self.orderRepository = orderRepository
    }

    func showBasket(userID: Int, basket: Basket) {
        let vc = makeBasketViewController(userID: userID, basket: basket)
        navigationController.pushViewController(vc, animated: true)
    }

    private func makeBasketViewController(userID: Int, basket: Basket) -> BasketViewController {
        let viewModel = BasketViewModel(
            userID: userID,
            basketID: basket.basketID,
            restaurantID: basket.restaurantID,
            fetchBasket: FetchBasketUseCase(repository: basketRepository),
            fetchDishes: FetchDishesUseCase(repository: dishRepository),
            createOrder: CreateOrderUseCase(repository: orderRepository)
        )
        viewModel.onOrderPlaced = { [weak self] order in
            self?.showOrderStatus(order: order)
        }
        return BasketViewController(viewModel: viewModel)
    }

    private func showOrderStatus(order: Order) {
        let viewModel = OrderStatusViewModel(initialOrder: order, orderService: orderService)
        let vc = OrderStatusViewController(viewModel: viewModel)
        navigationController.pushViewController(vc, animated: true)
    }
}
