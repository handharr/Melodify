import Foundation

final class DishLocalDataSource: DishLocalDataSourceProtocol, @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func fetchDishes(restaurantID: Int) -> [DishDTO]? {
        guard let data = defaults.data(forKey: key(restaurantID)) else { return nil }
        return try? JSONDecoder().decode([DishDTO].self, from: data)
    }

    func saveDishes(_ dtos: [DishDTO], restaurantID: Int) {
        defaults.set(try? JSONEncoder().encode(dtos), forKey: key(restaurantID))
    }

    private func key(_ restaurantID: Int) -> String { "ubereats.dishes.\(restaurantID)" }
}
