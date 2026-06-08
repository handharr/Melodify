// Data/DataSources/AmenityLocalDataSource.swift

import Foundation

final class AmenityLocalDataSource: AmenityLocalDataSourceProtocol, @unchecked Sendable {
    private var amenities: [AmenityDTO] = []
    private let lock = NSLock()

    func saveAmenities(_ dtos: [AmenityDTO]) {
        lock.lock()
        defer { lock.unlock() }
        amenities = dtos
    }

    func fetchAll() -> [AmenityDTO] {
        lock.lock()
        defer { lock.unlock() }
        return amenities
    }

    func find(amenityId: String) -> AmenityDTO? {
        lock.lock()
        defer { lock.unlock() }
        return amenities.first { $0.amenityId == amenityId }
    }
}
