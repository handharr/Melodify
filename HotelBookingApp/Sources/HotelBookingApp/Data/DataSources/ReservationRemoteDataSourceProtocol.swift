// Data/DataSources/ReservationRemoteDataSourceProtocol.swift

protocol ReservationRemoteDataSourceProtocol: Sendable {
    func createReservation(_ request: CreateReservationAPIRequest) async throws -> ReservationDTO
}
