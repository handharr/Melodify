enum HotelBookingError: Error {
    case roomUnavailable
    case paymentFailed
    case reservationExpired
    case notFound
}
