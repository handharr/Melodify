import Foundation

protocol ReservationRepositoryProtocol: Sendable {
    func createReservation(request: CreateReservationRequest) async throws -> Reservation
    func fetchReservations(request: FetchReservationsRequest) async throws -> [Reservation]
}
