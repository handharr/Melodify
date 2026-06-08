import Foundation

final class RestaurantLocalDataSource: RestaurantLocalDataSourceProtocol, @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func fetchRestaurants(addressID: Int) -> [RestaurantDTO]? {
        guard let data = defaults.data(forKey: key(addressID)) else { return nil }
        return try? JSONDecoder().decode([RestaurantDTO].self, from: data)
    }

    func saveRestaurants(_ dtos: [RestaurantDTO], addressID: Int) {
        defaults.set(try? JSONEncoder().encode(dtos), forKey: key(addressID))
    }

    private func key(_ addressID: Int) -> String { "ubereats.restaurants.\(addressID)" }
}
