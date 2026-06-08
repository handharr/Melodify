import Foundation

struct HotelDTO: Codable {
    let hotelId: String
    let amenities: [AmenityDTO]
    let rooms: [RoomDTO]
    let mediaUrls: MediaUrlsDTO
}
