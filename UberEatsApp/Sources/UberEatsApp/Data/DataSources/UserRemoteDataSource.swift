import Foundation
import CoreKit

final class UserRemoteDataSource: UserRemoteDataSourceProtocol {
    private let client: APIClientProtocol

    init(client: APIClientProtocol) {
        self.client = client
    }

    func fetchUser(_ request: FetchUserAPIRequest) async throws -> UserDTO {
        guard let url = request.url else { throw APIError.invalidURL }
        return try await client.get(url)
    }
}
