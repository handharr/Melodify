import Foundation

enum UserMapper {
    static func toDomain(_ dto: UserDTO) -> User? {
        let addresses = dto.addresses.map(AddressMapper.toDomain)
        guard let lastUsed = addresses.first(where: { $0.addressID == dto.lastUsedAddressID })
               ?? addresses.first else { return nil }
        return User(
            userID: dto.userID,
            name: dto.name,
            email: dto.email,
            addresses: addresses,
            lastUsedAddress: lastUsed
        )
    }
}
