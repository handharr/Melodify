import Foundation

struct HotelListingsDTO: Codable {
    let offset: Int
    let hotelListings: [HotelListingDTO]
}
