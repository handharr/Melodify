import Foundation

struct AddressDTO: Codable, Sendable {
    let addressID: Int
    let label: String
    let city: String
    let street: String
    let flat: String
    let postcode: String
    let latitude: Double
    let longitude: Double
}
