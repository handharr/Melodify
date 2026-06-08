import Foundation

enum AddressMapper {
    static func toDomain(_ dto: AddressDTO) -> Address {
        Address(
            addressID: dto.addressID,
            label: dto.label,
            city: dto.city,
            street: dto.street,
            flat: dto.flat,
            postcode: dto.postcode,
            latitude: dto.latitude,
            longitude: dto.longitude
        )
    }
}
