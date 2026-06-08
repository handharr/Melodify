import Foundation

enum HotelListingMapper {
    static func toDomain(_ dto: HotelListingDTO) -> HotelListing? {
        guard let thumbnailUrl = URL(string: dto.mediaUrl) else { return nil }
        return HotelListing(
            hotelId: dto.hotelId,
            location: dto.location,
            price: dto.price,
            rating: dto.rating,
            thumbnailUrl: thumbnailUrl
        )
    }
}
