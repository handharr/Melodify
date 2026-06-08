import Foundation

enum ReservationListUIModelMapper {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    static func toUIModel(_ model: Reservation) -> ReservationListItemUIModel {
        ReservationListItemUIModel(
            id: model.reservationId,
            hotelName: model.hotelName,
            checkIn: dateFormatter.string(from: model.checkIn),
            checkOut: dateFormatter.string(from: model.checkOut)
        )
    }
}
