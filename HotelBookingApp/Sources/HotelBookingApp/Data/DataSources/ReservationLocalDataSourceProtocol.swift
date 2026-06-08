// Data/DataSources/ReservationLocalDataSourceProtocol.swift

protocol ReservationLocalDataSourceProtocol {
    func save(_ dto: OfflineReservationDTO)
    func fetchAll() -> [OfflineReservationDTO]
}
