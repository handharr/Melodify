// Data/DataSources/HotelLocalDataSource.swift

import Foundation

final class HotelLocalDataSource: HotelLocalDataSourceProtocol, @unchecked Sendable {
    private var searchCache: [String: HotelListingsDTO] = [:]
    private var detailCache: [String: HotelDTO] = [:]
    private let lock = NSLock()

    // MARK: - Search

    func searchHotels(_ request: SearchHotelsAPIRequest) -> HotelListingsDTO? {
        lock.lock()
        defer { lock.unlock() }
        return searchCache[cacheKey(for: request)]
    }

    func saveSearchResults(_ dto: HotelListingsDTO, for request: SearchHotelsAPIRequest) {
        lock.lock()
        defer { lock.unlock() }
        searchCache[cacheKey(for: request)] = dto
    }

    // MARK: - Detail

    func fetchHotelDetail(_ request: FetchHotelDetailAPIRequest) -> HotelDTO? {
        lock.lock()
        defer { lock.unlock() }
        return detailCache[request.hotelId]
    }

    func saveHotelDetail(_ dto: HotelDTO, for request: FetchHotelDetailAPIRequest) {
        lock.lock()
        defer { lock.unlock() }
        detailCache[request.hotelId] = dto
    }

    // MARK: - Prefix Search

    func searchPrefix(query: String) -> [HotelListingDTO] {
        lock.lock()
        defer { lock.unlock() }
        let lowercased = query.lowercased()
        return searchCache.values
            .flatMap { $0.hotelListings }
            .filter { $0.location.lowercased().hasPrefix(lowercased) }
    }

    // MARK: - Private

    private func cacheKey(for request: SearchHotelsAPIRequest) -> String {
        "\(request.destination)|\(request.checkIn)|\(request.checkOut)|\(request.guestCount)|\(request.offset)|\(request.limit)"
    }
}
