import Foundation

enum HotelMapper {
    static func toDomain(_ dto: HotelDTO, amenityLibrary: [AmenityDTO]) -> Hotel? {
        let amenityLookup = Dictionary(uniqueKeysWithValues: amenityLibrary.map { ($0.amenityId, $0) })

        let amenities: [Amenity] = dto.amenities.compactMap { stub in
            guard let full = amenityLookup[stub.amenityId] else { return nil }
            return AmenityMapper.toDomain(full)
        }

        let rooms: [Room] = dto.rooms.compactMap { RoomMapper.toDomain($0) }

        let thumbnailUrls: [URL] = dto.mediaUrls.thumbnails.compactMap { URL(string: $0) }
        guard thumbnailUrls.count == dto.mediaUrls.thumbnails.count else { return nil }

        let fullSizeImageUrls: [URL] = dto.mediaUrls.fullSizeImages.compactMap { URL(string: $0) }
        guard fullSizeImageUrls.count == dto.mediaUrls.fullSizeImages.count else { return nil }

        return Hotel(
            hotelId: dto.hotelId,
            amenities: amenities,
            rooms: rooms,
            thumbnailUrls: thumbnailUrls,
            fullSizeImageUrls: fullSizeImageUrls
        )
    }
}
