import UIKit

@MainActor
final class RestaurantCoordinator {
    let navigationController: UINavigationController
    private var orderCoordinator: OrderCoordinator?
    private let userID: Int
    private let addressID: Int
    private let restaurantRepository: RestaurantRepositoryProtocol
    private let dishRepository: DishRepositoryProtocol
    private let basketRepository: BasketRepositoryProtocol
    private let orderRepository: OrderRepositoryProtocol
    private let sseDataSource: OrderSSEDataSourceProtocol

    init(
        navigationController: UINavigationController,
        userID: Int,
        addressID: Int,
        restaurantRepository: RestaurantRepositoryProtocol,
        dishRepository: DishRepositoryProtocol,
        basketRepository: BasketRepositoryProtocol,
        orderRepository: OrderRepositoryProtocol,
        sseDataSource: OrderSSEDataSourceProtocol
    ) {
        self.navigationController = navigationController
        self.userID = userID
        self.addressID = addressID
        self.restaurantRepository = restaurantRepository
        self.dishRepository = dishRepository
        self.basketRepository = basketRepository
        self.orderRepository = orderRepository
        self.sseDataSource = sseDataSource
    }

    func start() {
        navigationController.pushViewController(makeRestaurantListViewController(), animated: false)
    }

    private func makeRestaurantListViewController() -> RestaurantListViewController {
        let viewModel = RestaurantListViewModel(
            addressID: addressID,
            fetchRestaurants: FetchRestaurantsUseCase(repository: restaurantRepository)
        )
        viewModel.onSelectRestaurant = { [weak self] restaurant in
            self?.showMenu(for: restaurant)
        }
        return RestaurantListViewController(viewModel: viewModel)
    }

    private func showMenu(for restaurant: RestaurantUIModel) {
        let viewModel = MenuViewModel(
            restaurant: restaurant,
            userID: userID,
            fetchDishes: FetchDishesUseCase(repository: dishRepository),
            createBasket: CreateBasketUseCase(repository: basketRepository),
            updateBasket: UpdateBasketUseCase(repository: basketRepository)
        )
        viewModel.onBasketReady = { [weak self] basket in
            guard let self else { return }
            // OrderService is created here — scoped to the order flow, not app-scoped.
            let orderService = OrderService(sseDataSource: sseDataSource)
            let coordinator = OrderCoordinator(
                navigationController: navigationController,
                orderService: orderService,
                basketRepository: basketRepository,
                dishRepository: dishRepository,
                orderRepository: orderRepository
            )
            self.orderCoordinator = coordinator   // retain: prevents dealloc before nav completes
            coordinator.showBasket(userID: userID, basket: basket)
        }
        let vc = MenuViewController(viewModel: viewModel)
        vc.title = restaurant.name
        navigationController.pushViewController(vc, animated: true)
    }
}
