import Foundation

struct BasketUIModel {
    let basketID: Int
    let items: [BasketItemUIModel]
    let totalPrice: String

    struct BasketItemUIModel {
        let dishID: Int
        let name: String
        let count: String
        let price: String
    }

    static func from(_ basket: Basket, dishes: [Dish]) -> BasketUIModel {
        let dishMap = Dictionary(uniqueKeysWithValues: dishes.map { ($0.dishID, $0) })
        let items: [BasketItemUIModel] = basket.selectedDishes.compactMap { item in
            guard let dish = dishMap[item.dishID] else { return nil }
            return BasketItemUIModel(
                dishID: item.dishID,
                name: dish.name,
                count: "x\(item.count)",
                price: String(format: "$%.2f", dish.price * Double(item.count))
            )
        }
        let total = basket.selectedDishes.reduce(0.0) { sum, item in
            guard let dish = dishMap[item.dishID] else { return sum }
            return sum + dish.price * Double(item.count)
        }
        return BasketUIModel(
            basketID: basket.basketID,
            items: items,
            totalPrice: String(format: "Total: $%.2f", total)
        )
    }
}
