import Foundation

enum HotelDetailUIModelMapper {
    static func toUIModel(_ model: Hotel) -> HotelDetailUIModel {
        let amenityNames = model.amenities.map { $0.description }

        let rooms = model.rooms.map { room in
            RoomUIModel(
                id: room.roomId,
                bedsText: "\(room.numberOfBeds) Bed\(room.numberOfBeds == 1 ? "" : "s")",
                thumbnailURL: room.thumbnailUrl
            )
        }

        return HotelDetailUIModel(
            id: model.hotelId,
            amenityNames: amenityNames,
            rooms: rooms,
            thumbnailURLs: model.thumbnailUrls,
            fullSizeURLs: model.fullSizeImageUrls
        )
    }
}
