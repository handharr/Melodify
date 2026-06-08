import Foundation

struct DishUIModel {
    let dishID: Int
    let name: String
    let price: String
    let imageURL: URL

    static func from(_ dish: Dish) -> DishUIModel {
        DishUIModel(
            dishID: dish.dishID,
            name: dish.name,
            price: String(format: "$%.2f", dish.price),
            imageURL: dish.imageURL
        )
    }
}
