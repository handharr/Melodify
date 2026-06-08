import Foundation

struct OfflineReservationDTO {
    let reservationId: String
    let expirationTime: String
    let hotelName: String
    let checkIn: String
    let checkOut: String
    let roomIds: [String]
}
