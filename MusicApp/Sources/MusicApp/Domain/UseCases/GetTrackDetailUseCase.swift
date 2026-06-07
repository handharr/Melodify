import Foundation

protocol GetTrackDetailUseCaseProtocol: Sendable {
    func execute(request: GetTrackDetailRequest) async throws -> Track
}

final class GetTrackDetailUseCase: GetTrackDetailUseCaseProtocol, @unchecked Sendable {
    private let repository: TrackRepositoryProtocol

    init(repository: TrackRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: GetTrackDetailRequest) async throws -> Track {
        try await repository.getTrackDetail(request: request)
    }
}
