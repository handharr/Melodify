// Data/DataSources/ReservationLocalDataSource.swift

import Foundation

final class ReservationLocalDataSource: ReservationLocalDataSourceProtocol, @unchecked Sendable {
    private var reservations: [OfflineReservationDTO] = []
    private let lock = NSLock()

    func save(_ dto: OfflineReservationDTO) {
        lock.lock()
        defer { lock.unlock() }
        reservations.append(dto)
    }

    func fetchAll() -> [OfflineReservationDTO] {
        lock.lock()
        defer { lock.unlock() }
        return reservations
    }
}
