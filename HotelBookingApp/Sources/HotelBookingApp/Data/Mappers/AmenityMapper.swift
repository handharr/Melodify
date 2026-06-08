import Foundation

enum AmenityMapper {
    static func toDomain(_ dto: AmenityDTO) -> Amenity? {
        guard let iconUrl = URL(string: dto.iconUrl) else { return nil }
        return Amenity(
            amenityId: dto.amenityId,
            description: dto.amenityDescription,
            iconUrl: iconUrl
        )
    }
}
