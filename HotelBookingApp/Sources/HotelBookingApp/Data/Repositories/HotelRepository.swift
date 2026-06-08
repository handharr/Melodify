import Foundation
import CoreKit

final class HotelRepository: HotelRepositoryProtocol, @unchecked Sendable {

    private let remoteDataSource: HotelRemoteDataSourceProtocol
    private let localDataSource: HotelLocalDataSourceProtocol

    init(
        remoteDataSource: HotelRemoteDataSourceProtocol,
        localDataSource: HotelLocalDataSourceProtocol
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }

    // MARK: - HotelRepositoryProtocol

    func searchHotels(request: SearchHotelsRequest) async throws -> [HotelListing] {
        let policy = request.policy
        let apiRequest = SearchHotelsAPIRequest(
            destination: request.query.destination,
            checkIn: request.query.checkIn,
            checkOut: request.query.checkOut,
            guestCount: request.query.guestCount,
            offset: request.query.offset,
            limit: request.query.limit
        )

        if !policy.force && !policy.allowStale {
            guard let cached = localDataSource.searchHotels(apiRequest) else {
                throw APIError.notFound
            }
            return cached.hotelListings.compactMap { HotelListingMapper.toDomain($0) }
        }

        if !policy.force, let cached = localDataSource.searchHotels(apiRequest) {
            return cached.hotelListings.compactMap { HotelListingMapper.toDomain($0) }
        }

        let dto = try await remoteDataSource.searchHotels(apiRequest)
        localDataSource.saveSearchResults(dto, for: apiRequest)
        return dto.hotelListings.compactMap { HotelListingMapper.toDomain($0) }
    }

    func fetchHotelDetail(request: FetchHotelDetailRequest) async throws -> Hotel {
        let policy = request.policy
        let apiRequest = FetchHotelDetailAPIRequest(hotelId: request.path.hotelId)

        if !policy.force && !policy.allowStale {
            guard let cached = localDataSource.fetchHotelDetail(apiRequest),
                  let hotel = HotelMapper.toDomain(cached, amenityLibrary: []) else {
                throw APIError.notFound
            }
            return hotel
        }

        if !policy.force,
           let cached = localDataSource.fetchHotelDetail(apiRequest),
           let hotel = HotelMapper.toDomain(cached, amenityLibrary: []) {
            return hotel
        }

        let dto = try await remoteDataSource.fetchHotelDetail(apiRequest)
        localDataSource.saveHotelDetail(dto, for: apiRequest)
        guard let hotel = HotelMapper.toDomain(dto, amenityLibrary: []) else {
            throw APIError.notFound
        }
        return hotel
    }
}
