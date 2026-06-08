import Foundation

protocol FetchReservationsUseCaseProtocol: Sendable {
    func execute(request: FetchReservationsRequest) async throws -> [Reservation]
}

final class FetchReservationsUseCase: FetchReservationsUseCaseProtocol, @unchecked Sendable {
    private let repository: ReservationRepositoryProtocol

    init(repository: ReservationRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: FetchReservationsRequest) async throws -> [Reservation] {
        try await repository.fetchReservations(request: request)
    }
}
