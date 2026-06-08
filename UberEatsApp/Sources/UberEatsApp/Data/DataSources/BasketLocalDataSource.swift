import Foundation

final class BasketLocalDataSource: BasketLocalDataSourceProtocol, @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func fetchBasket(basketID: Int) -> BasketDTO? {
        guard let data = defaults.data(forKey: key(basketID)) else { return nil }
        return try? JSONDecoder().decode(BasketDTO.self, from: data)
    }

    func saveBasket(_ dto: BasketDTO) {
        defaults.set(try? JSONEncoder().encode(dto), forKey: key(dto.basketID))
    }

    private func key(_ basketID: Int) -> String { "ubereats.basket.\(basketID)" }
}
