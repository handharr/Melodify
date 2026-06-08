import Foundation

struct ProcessPaymentAPIRequest: Encodable, Sendable {
    let paymentToken: String
    let reservationId: String
}
