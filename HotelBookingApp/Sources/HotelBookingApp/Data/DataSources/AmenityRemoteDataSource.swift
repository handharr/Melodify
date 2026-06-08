// Data/DataSources/AmenityRemoteDataSource.swift

import Foundation
import CoreKit

final class AmenityRemoteDataSource: AmenityRemoteDataSourceProtocol {
    private let client: APIClientProtocol
    private let baseURL = "https://hotel-booking-api.example.com/v1"

    init(client: APIClientProtocol) {
        self.client = client
    }

    func fetchAmenities() async throws -> [AmenityDTO] {
        guard let url = URL(string: "\(baseURL)/amenities") else {
            throw APIError.invalidURL
        }
        return try await client.get(url)
    }
}
