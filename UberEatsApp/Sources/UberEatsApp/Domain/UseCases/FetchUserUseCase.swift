import Foundation

protocol FetchUserUseCaseProtocol: Sendable {
    func execute(request: FetchUserRequest) async throws -> User
}

final class FetchUserUseCase: FetchUserUseCaseProtocol, @unchecked Sendable {
    private let repository: UserRepositoryProtocol

    init(repository: UserRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: FetchUserRequest) async throws -> User {
        try await repository.fetchUser(request: request)
    }
}
