import Foundation

struct FetchRestaurantsAPIRequest {
    let addressID: Int
    var url: URL? { URL(string: "https://api.ubereats-mock.com/v1/restaurants/\(addressID)") }
}
