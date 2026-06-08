import Foundation

protocol UserRepositoryProtocol: Sendable {
    func fetchUser(request: FetchUserRequest) async throws -> User
}
