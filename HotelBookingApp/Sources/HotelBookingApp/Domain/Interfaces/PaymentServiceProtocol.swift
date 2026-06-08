import Foundation

protocol PaymentServiceProtocol: AnyObject, Sendable {
    func pay(reservationId: String) async throws
}
