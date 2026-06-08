import Foundation
import CoreKit

final class AmenityRepository: AmenityRepositoryProtocol, @unchecked Sendable {

    private let remoteDataSource: AmenityRemoteDataSourceProtocol
    private let localDataSource: AmenityLocalDataSourceProtocol

    init(
        remoteDataSource: AmenityRemoteDataSourceProtocol,
        localDataSource: AmenityLocalDataSourceProtocol
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }

    // MARK: - AmenityRepositoryProtocol

    func fetchAmenities(request: FetchAmenitiesRequest) async throws -> [Amenity] {
        let policy = request.policy

        if !policy.force && !policy.allowStale {
            return localDataSource.fetchAll().compactMap { AmenityMapper.toDomain($0) }
        }

        if !policy.force {
            let cached = localDataSource.fetchAll()
            if !cached.isEmpty {
                return cached.compactMap { AmenityMapper.toDomain($0) }
            }
        }

        let dtos = try await remoteDataSource.fetchAmenities()
        localDataSource.saveAmenities(dtos)
        return dtos.compactMap { AmenityMapper.toDomain($0) }
    }
}
