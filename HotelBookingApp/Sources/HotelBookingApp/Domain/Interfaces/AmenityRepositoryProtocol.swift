import Foundation

protocol AmenityRepositoryProtocol: Sendable {
    func fetchAmenities(request: FetchAmenitiesRequest) async throws -> [Amenity]
}
