// Data/DataSources/PaymentRemoteDataSource.swift

import Foundation
import CoreKit

final class PaymentRemoteDataSource: PaymentRemoteDataSourceProtocol {
    private let client: APIClientProtocol
    private let baseURL = "https://hotel-booking-api.example.com/v1"

    init(client: APIClientProtocol) {
        self.client = client
    }

    func processPayment(_ request: ProcessPaymentAPIRequest) async throws {
        guard let url = URL(string: "\(baseURL)/reservations/payment") else {
            throw APIError.invalidURL
        }
        let _: EmptyResponse = try await client.post(url, body: request)
    }
}

private struct EmptyResponse: Codable {}
