import Foundation

protocol DishLocalDataSourceProtocol: Sendable {
    func fetchDishes(restaurantID: Int) -> [DishDTO]?
    func saveDishes(_ dtos: [DishDTO], restaurantID: Int)
}
