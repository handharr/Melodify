import Foundation

protocol UserRemoteDataSourceProtocol: Sendable {
    func fetchUser(_ request: FetchUserAPIRequest) async throws -> UserDTO
}
