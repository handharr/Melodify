import Foundation

protocol FetchAmenitiesUseCaseProtocol: Sendable {
    func execute(request: FetchAmenitiesRequest) async throws -> [Amenity]
}

final class FetchAmenitiesUseCase: FetchAmenitiesUseCaseProtocol, @unchecked Sendable {
    private let repository: AmenityRepositoryProtocol

    init(repository: AmenityRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: FetchAmenitiesRequest) async throws -> [Amenity] {
        try await repository.fetchAmenities(request: request)
    }
}
