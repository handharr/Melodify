// Data/DataSources/ReservationRemoteDataSource.swift

import Foundation
import CoreKit

final class ReservationRemoteDataSource: ReservationRemoteDataSourceProtocol {
    private let client: APIClientProtocol
    private let baseURL = "https://hotel-booking-api.example.com/v1"

    init(client: APIClientProtocol) {
        self.client = client
    }

    func createReservation(_ request: CreateReservationAPIRequest) async throws -> ReservationDTO {
        guard let url = URL(string: "\(baseURL)/reservations") else {
            throw APIError.invalidURL
        }
        return try await client.post(url, body: request)
    }
}
