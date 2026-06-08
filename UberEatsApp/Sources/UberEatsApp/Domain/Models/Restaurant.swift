import Foundation

struct Restaurant: Sendable {
    let restaurantID: Int
    let name: String
    let rating: Int
    let address: Address
    let imageURL: URL
}
