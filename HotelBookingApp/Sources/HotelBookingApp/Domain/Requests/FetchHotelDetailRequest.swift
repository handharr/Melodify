import Foundation

struct FetchHotelDetailPath: Sendable, Equatable {
    let hotelId: String
}

typealias FetchHotelDetailRequest = Request<Void, FetchHotelDetailPath>
