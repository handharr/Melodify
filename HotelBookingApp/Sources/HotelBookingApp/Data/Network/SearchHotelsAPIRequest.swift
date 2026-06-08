import Foundation

struct SearchHotelsAPIRequest {
    let destination: String
    let checkIn: String
    let checkOut: String
    let guestCount: Int
    let offset: Int
    let limit: Int
}
