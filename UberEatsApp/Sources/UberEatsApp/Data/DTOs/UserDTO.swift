import Foundation

struct UserDTO: Codable, Sendable {
    let userID: Int
    let name: String
    let email: String
    let addresses: [AddressDTO]
    let lastUsedAddressID: Int
}
