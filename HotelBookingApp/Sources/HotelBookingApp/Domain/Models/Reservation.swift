import Foundation

struct Reservation: Sendable {
    let reservationId: String
    let expirationTime: Date
    let hotelName: String
    let checkIn: Date
    let checkOut: Date
    let roomIds: [String]
}
