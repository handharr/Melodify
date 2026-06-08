import Foundation

struct HotelDetailUIModel {
    let id: String
    let amenityNames: [String]
    let rooms: [RoomUIModel]
    let thumbnailURLs: [URL]
    let fullSizeURLs: [URL]
}

struct RoomUIModel: Identifiable {
    let id: String
    let bedsText: String
    let thumbnailURL: URL?
}
