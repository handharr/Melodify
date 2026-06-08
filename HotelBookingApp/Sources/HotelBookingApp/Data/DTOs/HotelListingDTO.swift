import Foundation

struct HotelListingDTO: Codable {
    let hotelId: String
    let location: String
    let rating: String
    let mediaUrl: String
    let price: Decimal
}
