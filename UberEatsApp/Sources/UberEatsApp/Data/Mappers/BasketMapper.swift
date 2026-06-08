import Foundation

enum BasketMapper {
    static func toDomain(_ dto: BasketDTO) -> Basket {
        Basket(
            basketID: dto.basketID,
            userID: dto.userID,
            restaurantID: dto.restaurantID,
            selectedDishes: dto.selectedDishes.map { ($0.dishID, $0.count) }
        )
    }

    static func toDTO(_ basket: Basket) -> BasketDTO {
        BasketDTO(
            basketID: basket.basketID,
            userID: basket.userID,
            restaurantID: basket.restaurantID,
            selectedDishes: basket.selectedDishes.map { BasketItemDTO(dishID: $0.dishID, count: $0.count) }
        )
    }
}
