import Foundation
import Combine

@MainActor
final class PaymentViewModel: ObservableObject {

    // MARK: - Output state

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    // MARK: - Coordinator callback

    var onPaymentComplete: (() -> Void)?

    // MARK: - Private

    private let reservationId: String
    private let paymentService: PaymentServiceProtocol

    // MARK: - Init

    init(reservationId: String, paymentService: PaymentServiceProtocol) {
        self.reservationId = reservationId
        self.paymentService = paymentService
    }

    // MARK: - Pay

    func pay() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            try await paymentService.pay(reservationId: reservationId)
            onPaymentComplete?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
