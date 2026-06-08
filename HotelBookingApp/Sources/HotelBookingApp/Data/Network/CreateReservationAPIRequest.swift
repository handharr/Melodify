import Foundation

struct CreateReservationAPIRequest: Encodable, Sendable {
    let localId: String
    let hotelId: String
    let roomIds: [String]
    let guestCount: Int
}
