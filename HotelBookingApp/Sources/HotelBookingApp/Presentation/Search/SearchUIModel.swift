import Foundation

struct SearchUIModel {
    var destination: String
    var checkIn: String
    var checkOut: String
    var guestCount: Int
}

struct HotelCardUIModel: Identifiable {
    let id: String
    let name: String
    let location: String
    let priceText: String
    let rating: String
    let thumbnailURL: URL?
}
