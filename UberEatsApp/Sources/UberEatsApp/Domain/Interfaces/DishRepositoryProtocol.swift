import Foundation

protocol DishRepositoryProtocol: Sendable {
    func fetchDishes(request: FetchDishesRequest) async throws -> [Dish]
}
