import Foundation

struct HotelListing: Sendable {
    let hotelId: String
    let location: String
    let price: Decimal
    let rating: String
    let thumbnailUrl: URL
}
