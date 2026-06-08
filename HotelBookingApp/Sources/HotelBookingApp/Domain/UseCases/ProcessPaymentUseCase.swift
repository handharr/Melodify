import Foundation

protocol ProcessPaymentUseCaseProtocol: Sendable {
    func execute(request: ProcessPaymentRequest) async throws
}

final class ProcessPaymentUseCase: ProcessPaymentUseCaseProtocol, @unchecked Sendable {
    private let repository: PaymentRepositoryProtocol

    init(repository: PaymentRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: ProcessPaymentRequest) async throws {
        try await repository.processPayment(request: request)
    }
}
