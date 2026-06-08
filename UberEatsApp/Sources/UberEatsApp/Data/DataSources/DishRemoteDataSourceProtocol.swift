import Foundation

protocol DishRemoteDataSourceProtocol: Sendable {
    func fetchDishes(_ request: FetchDishesAPIRequest) async throws -> [DishDTO]
}
