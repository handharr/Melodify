import Foundation

final class PaymentService: PaymentServiceProtocol, @unchecked Sendable {
    private let gateway: PaymentGatewayProtocol
    private let processPaymentUseCase: ProcessPaymentUseCaseProtocol

    init(gateway: PaymentGatewayProtocol, processPaymentUseCase: ProcessPaymentUseCaseProtocol) {
        self.gateway = gateway
        self.processPaymentUseCase = processPaymentUseCase
    }

    func pay(reservationId: String) async throws {
        let token = try await gateway.collectToken()
        try await processPaymentUseCase.execute(
            request: ProcessPaymentRequest(
                query: ProcessPaymentQuery(paymentToken: token, reservationId: reservationId)
            )
        )
    }
}
