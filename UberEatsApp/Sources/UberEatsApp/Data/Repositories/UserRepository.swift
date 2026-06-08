import Foundation

final class UserRepository: UserRepositoryProtocol, @unchecked Sendable {
    private let remoteDataSource: UserRemoteDataSourceProtocol
    private let localDataSource: UserLocalDataSourceProtocol

    init(remoteDataSource: UserRemoteDataSourceProtocol, localDataSource: UserLocalDataSourceProtocol) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }

    func fetchUser(request: FetchUserRequest) async throws -> User {
        let policy = request.policy
        let apiRequest = FetchUserAPIRequest(userID: request.path.userID)

        // .strict — cache only, throw on miss
        if !policy.force && !policy.allowStale {
            guard let cached = localDataSource.fetchUser(),
                  let user = UserMapper.toDomain(cached) else { throw UberEatsError.notFound }
            return user
        }

        // .cached — return cache if available, else fetch
        if !policy.force, let cached = localDataSource.fetchUser(),
           let user = UserMapper.toDomain(cached) {
            return user
        }

        // .fresh — always hit the network
        let dto = try await remoteDataSource.fetchUser(apiRequest)
        localDataSource.saveUser(dto)
        guard let user = UserMapper.toDomain(dto) else { throw UberEatsError.notFound }
        return user
    }
}
