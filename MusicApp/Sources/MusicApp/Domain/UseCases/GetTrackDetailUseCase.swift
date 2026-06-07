import Foundation

protocol GetTrackDetailUseCaseProtocol: Sendable {
    func execute(policy: FetchPolicy, param: GetTrackDetailParam) async throws -> Track
}

final class GetTrackDetailUseCase: GetTrackDetailUseCaseProtocol, @unchecked Sendable {
    private let repository: TrackRepositoryProtocol

    init(repository: TrackRepositoryProtocol) {
        self.repository = repository
    }

    func execute(policy: FetchPolicy, param: GetTrackDetailParam) async throws -> Track {
        try await repository.getTrackDetail(policy: policy, param: param)
    }
}
