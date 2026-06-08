import Foundation
import Combine

@MainActor
final class BasketViewModel {
    @Published private(set) var basket: BasketUIModel?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let userID: Int
    private let basketID: Int
    private let restaurantID: Int
    private let fetchBasket: FetchBasketUseCaseProtocol
    private let fetchDishes: FetchDishesUseCaseProtocol
    private let createOrder: CreateOrderUseCaseProtocol

    var onOrderPlaced: ((Order) -> Void)?

    init(
        userID: Int,
        basketID: Int,
        restaurantID: Int,
        fetchBasket: FetchBasketUseCaseProtocol,
        fetchDishes: FetchDishesUseCaseProtocol,
        createOrder: CreateOrderUseCaseProtocol
    ) {
        self.userID = userID
        self.basketID = basketID
        self.restaurantID = restaurantID
        self.fetchBasket = fetchBasket
        self.fetchDishes = fetchDishes
        self.createOrder = createOrder
    }

    func load() {
        Task {
            defer { isLoading = false }
            isLoading = true
            do {
                async let basketResult = fetchBasket.execute(
                    request: FetchBasketRequest(path: FetchBasketPath(basketID: basketID), policy: .cached)
                )
                async let dishesResult = fetchDishes.execute(
                    request: FetchDishesRequest(path: FetchDishesPath(restaurantID: restaurantID), policy: .cached)
                )
                let (loadedBasket, dishes) = try await (basketResult, dishesResult)
                basket = BasketUIModel.from(loadedBasket, dishes: dishes)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func placeOrder() {
        Task {
            defer { isLoading = false }
            isLoading = true
            do {
                // Idempotency key generated at the call site — not in Repository or DataSource.
                let order = try await createOrder.execute(
                    request: CreateOrderRequest(
                        query: CreateOrderQuery(
                            userID: userID,
                            basketID: basketID,
                            idempotencyKey: UUID()
                        )
                    )
                )
                onOrderPlaced?(order)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
