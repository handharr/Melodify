import Foundation

protocol BasketLocalDataSourceProtocol: Sendable {
    func fetchBasket(basketID: Int) -> BasketDTO?
    func saveBasket(_ dto: BasketDTO)
}
