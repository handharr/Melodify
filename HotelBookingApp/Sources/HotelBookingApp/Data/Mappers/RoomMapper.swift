import Foundation

enum RoomMapper {
    static func toDomain(_ dto: RoomDTO) -> Room? {
        guard let thumbnailUrl = URL(string: dto.mediaUrl) else { return nil }
        return Room(
            roomId: dto.roomId,
            numberOfBeds: dto.numberOfBeds,
            thumbnailUrl: thumbnailUrl
        )
    }
}
