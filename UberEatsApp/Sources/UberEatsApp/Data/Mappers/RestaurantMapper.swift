import Foundation

enum RestaurantMapper {
    static func toDomain(_ dto: RestaurantDTO) -> Restaurant? {
        guard let imageURL = URL(string: dto.imageURL) else { return nil }
        return Restaurant(
            restaurantID: dto.restaurantID,
            name: dto.name,
            rating: dto.rating,
            address: AddressMapper.toDomain(dto.address),
            imageURL: imageURL
        )
    }
}
