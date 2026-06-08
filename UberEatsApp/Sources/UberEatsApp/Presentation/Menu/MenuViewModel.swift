import Foundation
import Combine

@MainActor
final class MenuViewModel {
    @Published private(set) var dishes: [DishUIModel] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let restaurant: RestaurantUIModel
    private let userID: Int
    private var basketID: Int?
    private let fetchDishes: FetchDishesUseCaseProtocol
    private let createBasket: CreateBasketUseCaseProtocol
    private let updateBasket: UpdateBasketUseCaseProtocol

    var onBasketReady: ((Basket) -> Void)?

    init(
        restaurant: RestaurantUIModel,
        userID: Int,
        fetchDishes: FetchDishesUseCaseProtocol,
        createBasket: CreateBasketUseCaseProtocol,
        updateBasket: UpdateBasketUseCaseProtocol
    ) {
        self.restaurant = restaurant
        self.userID = userID
        self.fetchDishes = fetchDishes
        self.createBasket = createBasket
        self.updateBasket = updateBasket
    }

    func load() {
        Task {
            defer { isLoading = false }
            isLoading = true
            do {
                let result = try await fetchDishes.execute(
                    request: FetchDishesRequest(
                        path: FetchDishesPath(restaurantID: restaurant.restaurantID),
                        policy: .cached
                    )
                )
                dishes = result.map(DishUIModel.from)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func addDish(_ model: DishUIModel) {
        Task {
            do {
                let basket: Basket
                if let existingBasketID = basketID {
                    basket = try await updateBasket.execute(
                        request: UpdateBasketRequest(
                            query: UpdateBasketQuery(basketID: existingBasketID, dishID: model.dishID, count: 1)
                        )
                    )
                } else {
                    basket = try await createBasket.execute(
                        request: CreateBasketRequest(
                            query: CreateBasketQuery(
                                userID: userID,
                                restaurantID: restaurant.restaurantID,
                                dishID: model.dishID,
                                count: 1
                            )
                        )
                    )
                    basketID = basket.basketID
                }
                onBasketReady?(basket)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
