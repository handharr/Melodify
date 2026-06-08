// Data/DataSources/AmenityRemoteDataSourceProtocol.swift

protocol AmenityRemoteDataSourceProtocol: Sendable {
    func fetchAmenities() async throws -> [AmenityDTO]
}
