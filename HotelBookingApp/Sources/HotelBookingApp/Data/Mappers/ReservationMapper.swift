import Foundation

enum ReservationMapper {
    static func toDomain(
        dto: ReservationDTO,
        hotelName: String,
        checkIn: Date,
        checkOut: Date,
        roomIds: [String]
    ) -> Reservation? {
        let formatter = ISO8601DateFormatter()
        guard let expirationTime = formatter.date(from: dto.expirationTime) else { return nil }
        return Reservation(
            reservationId: dto.reservationId,
            expirationTime: expirationTime,
            hotelName: hotelName,
            checkIn: checkIn,
            checkOut: checkOut,
            roomIds: roomIds
        )
    }

    static func toDomain(_ dto: OfflineReservationDTO) -> Reservation? {
        let formatter = ISO8601DateFormatter()
        guard let expirationTime = formatter.date(from: dto.expirationTime) else { return nil }
        let checkIn = formatter.date(from: dto.checkIn) ?? Date.distantPast
        let checkOut = formatter.date(from: dto.checkOut) ?? Date.distantFuture
        return Reservation(
            reservationId: dto.reservationId,
            expirationTime: expirationTime,
            hotelName: dto.hotelName,
            checkIn: checkIn,
            checkOut: checkOut,
            roomIds: dto.roomIds
        )
    }
}
