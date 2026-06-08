import Foundation

struct ProcessPaymentQuery: Sendable, Equatable {
    let paymentToken: String
    let reservationId: String
}

typealias ProcessPaymentRequest = Request<ProcessPaymentQuery, Void>
