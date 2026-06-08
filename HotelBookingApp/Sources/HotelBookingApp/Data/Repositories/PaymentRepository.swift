import Foundation
import CoreKit

final class PaymentRepository: PaymentRepositoryProtocol, @unchecked Sendable {

    private let remoteDataSource: PaymentRemoteDataSourceProtocol

    init(remoteDataSource: PaymentRemoteDataSourceProtocol) {
        self.remoteDataSource = remoteDataSource
    }

    // MARK: - PaymentRepositoryProtocol

    func processPayment(request: ProcessPaymentRequest) async throws {
        let apiRequest = ProcessPaymentAPIRequest(
            paymentToken: request.query.paymentToken,
            reservationId: request.query.reservationId
        )
        do {
            try await remoteDataSource.processPayment(apiRequest)
        } catch APIError.conflict {
            throw HotelBookingError.paymentFailed
        }
    }
}
