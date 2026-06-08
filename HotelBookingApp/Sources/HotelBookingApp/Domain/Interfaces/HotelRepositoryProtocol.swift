import Foundation

protocol HotelRepositoryProtocol: Sendable {
    func searchHotels(request: SearchHotelsRequest) async throws -> [HotelListing]
    func fetchHotelDetail(request: FetchHotelDetailRequest) async throws -> Hotel
}
