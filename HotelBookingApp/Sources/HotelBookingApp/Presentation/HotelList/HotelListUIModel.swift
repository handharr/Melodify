import Foundation

struct HotelListUIModel: Identifiable {
    let id: String
    let name: String
    let location: String
    let priceText: String
    let rating: String
    let thumbnailURL: URL?
}
