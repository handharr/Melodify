// Data/DataSources/HotelLocalDataSourceProtocol.swift

protocol HotelLocalDataSourceProtocol {
    func searchHotels(_ request: SearchHotelsAPIRequest) -> HotelListingsDTO?
    func saveSearchResults(_ dto: HotelListingsDTO, for request: SearchHotelsAPIRequest)
    func fetchHotelDetail(_ request: FetchHotelDetailAPIRequest) -> HotelDTO?
    func saveHotelDetail(_ dto: HotelDTO, for request: FetchHotelDetailAPIRequest)
    func searchPrefix(query: String) -> [HotelListingDTO]
}
