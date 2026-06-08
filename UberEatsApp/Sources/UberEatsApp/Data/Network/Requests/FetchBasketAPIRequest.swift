import Foundation

struct FetchBasketAPIRequest {
    let basketID: Int
    var url: URL? { URL(string: "https://api.ubereats-mock.com/v1/basket/\(basketID)") }
}
