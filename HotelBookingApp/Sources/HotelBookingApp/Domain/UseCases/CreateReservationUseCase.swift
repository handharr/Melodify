import Foundation

protocol CreateReservationUseCaseProtocol: Sendable {
    func execute(request: CreateReservationRequest) async throws -> Reservation
}

final class CreateReservationUseCase: CreateReservationUseCaseProtocol, @unchecked Sendable {
    private let repository: ReservationRepositoryProtocol

    init(repository: ReservationRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: CreateReservationRequest) async throws -> Reservation {
        try await repository.createReservation(request: request)
    }
}
