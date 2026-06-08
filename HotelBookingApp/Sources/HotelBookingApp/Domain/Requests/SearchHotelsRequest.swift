import Foundation

struct SearchHotelsQuery: Sendable, Equatable {
    let destination: String
    let checkIn: String
    let checkOut: String
    let guestCount: Int
    let offset: Int
    let limit: Int

    init(
        destination: String,
        checkIn: String,
        checkOut: String,
        guestCount: Int,
        offset: Int = 0,
        limit: Int = 25
    ) {
        self.destination = destination
        self.checkIn = checkIn
        self.checkOut = checkOut
        self.guestCount = guestCount
        self.offset = offset
        self.limit = limit
    }
}

typealias SearchHotelsRequest = Request<SearchHotelsQuery, Void>
