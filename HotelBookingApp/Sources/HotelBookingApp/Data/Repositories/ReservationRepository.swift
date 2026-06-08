import Foundation
import CoreKit

final class ReservationRepository: ReservationRepositoryProtocol, @unchecked Sendable {

    private let remoteDataSource: ReservationRemoteDataSourceProtocol
    private let localDataSource: ReservationLocalDataSourceProtocol

    init(
        remoteDataSource: ReservationRemoteDataSourceProtocol,
        localDataSource: ReservationLocalDataSourceProtocol
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }

    // MARK: - ReservationRepositoryProtocol

    func createReservation(request: CreateReservationRequest) async throws -> Reservation {
        let apiRequest = CreateReservationAPIRequest(
            localId: request.query.localId.uuidString,
            hotelId: request.query.hotelId,
            roomIds: request.query.roomIds,
            guestCount: request.query.guestCount
        )

        let dto = try await remoteDataSource.createReservation(apiRequest)

        let offlineDTO = OfflineReservationDTO(
            reservationId: dto.reservationId,
            expirationTime: dto.expirationTime,
            hotelName: request.query.hotelId,
            checkIn: "",
            checkOut: "",
            roomIds: request.query.roomIds
        )
        localDataSource.save(offlineDTO)

        guard let reservation = ReservationMapper.toDomain(offlineDTO) else {
            throw APIError.notFound
        }
        return reservation
    }

    func fetchReservations(request: FetchReservationsRequest) async throws -> [Reservation] {
        let dtos = localDataSource.fetchAll()
        return dtos.compactMap { ReservationMapper.toDomain($0) }
    }
}
