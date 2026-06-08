import Foundation

struct User: Sendable {
    let userID: Int
    let name: String
    let email: String
    let addresses: [Address]
    let lastUsedAddress: Address
}
