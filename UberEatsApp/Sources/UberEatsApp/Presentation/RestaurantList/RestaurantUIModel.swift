import Foundation

struct RestaurantUIModel {
    let restaurantID: Int
    let name: String
    let rating: String
    let imageURL: URL

    static func from(_ restaurant: Restaurant) -> RestaurantUIModel {
        RestaurantUIModel(
            restaurantID: restaurant.restaurantID,
            name: restaurant.name,
            rating: "★ \(restaurant.rating)",
            imageURL: restaurant.imageURL
        )
    }
}
