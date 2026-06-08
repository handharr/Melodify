import Foundation

protocol PaymentRepositoryProtocol: Sendable {
    func processPayment(request: ProcessPaymentRequest) async throws
}
