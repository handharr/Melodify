// Data/DataSources/HotelRemoteDataSourceProtocol.swift

protocol HotelRemoteDataSourceProtocol: Sendable {
    func searchHotels(_ request: SearchHotelsAPIRequest) async throws -> HotelListingsDTO
    func fetchHotelDetail(_ request: FetchHotelDetailAPIRequest) async throws -> HotelDTO
}
