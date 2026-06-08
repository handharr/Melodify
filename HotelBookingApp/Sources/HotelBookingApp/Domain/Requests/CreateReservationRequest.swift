import Foundation

struct CreateReservationQuery: Sendable, Equatable {
    let localId: UUID
    let hotelId: String
    let roomIds: [String]
    let guestCount: Int
}

typealias CreateReservationRequest = Request<CreateReservationQuery, Void>
