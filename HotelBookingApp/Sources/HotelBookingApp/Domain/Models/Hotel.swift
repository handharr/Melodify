import Foundation

struct Hotel: Sendable {
    let hotelId: String
    let amenities: [Amenity]
    let rooms: [Room]
    let thumbnailUrls: [URL]
    let fullSizeImageUrls: [URL]
}
