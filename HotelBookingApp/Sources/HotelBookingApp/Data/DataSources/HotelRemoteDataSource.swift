// Data/DataSources/HotelRemoteDataSource.swift

import Foundation
import CoreKit

final class HotelRemoteDataSource: HotelRemoteDataSourceProtocol {
    private let client: APIClientProtocol
    private let baseURL = "https://hotel-booking-api.example.com/v1"

    init(client: APIClientProtocol) {
        self.client = client
    }

    func searchHotels(_ request: SearchHotelsAPIRequest) async throws -> HotelListingsDTO {
        var components = URLComponents(string: "\(baseURL)/hotels")
        components?.queryItems = [
            URLQueryItem(name: "destination", value: request.destination),
            URLQueryItem(name: "check_in", value: request.checkIn),
            URLQueryItem(name: "check_out", value: request.checkOut),
            URLQueryItem(name: "guest_count", value: String(request.guestCount)),
            URLQueryItem(name: "offset", value: String(request.offset)),
            URLQueryItem(name: "limit", value: String(request.limit))
        ]
        guard let url = components?.url else { throw APIError.invalidURL }
        return try await client.get(url)
    }

    func fetchHotelDetail(_ request: FetchHotelDetailAPIRequest) async throws -> HotelDTO {
        guard let url = URL(string: "\(baseURL)/hotels/\(request.hotelId)") else {
            throw APIError.invalidURL
        }
        return try await client.get(url)
    }
}
