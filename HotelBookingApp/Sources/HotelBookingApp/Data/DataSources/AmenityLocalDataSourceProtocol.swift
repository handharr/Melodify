// Data/DataSources/AmenityLocalDataSourceProtocol.swift

protocol AmenityLocalDataSourceProtocol {
    func saveAmenities(_ dtos: [AmenityDTO])
    func fetchAll() -> [AmenityDTO]
    func find(amenityId: String) -> AmenityDTO?
}
