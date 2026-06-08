import Foundation

enum DishMapper {
    static func toDomain(_ dto: DishDTO) -> Dish? {
        guard let imageURL = URL(string: dto.imageURL) else { return nil }
        return Dish(
            dishID: dto.dishID,
            restaurantID: dto.restaurantID,
            name: dto.name,
            price: dto.price,
            imageURL: imageURL
        )
    }
}
