import Foundation

struct FetchDishesAPIRequest {
    let restaurantID: Int
    var url: URL? { URL(string: "https://api.ubereats-mock.com/v1/dishes/\(restaurantID)") }
}
