import Foundation

protocol SearchTracksUseCaseProtocol: Sendable {
    func execute(policy: FetchPolicy, param: SearchTracksParam) async throws -> [Track]
}

final class SearchTracksUseCase: SearchTracksUseCaseProtocol, @unchecked Sendable {
    private let repository: TrackRepositoryProtocol

    init(repository: TrackRepositoryProtocol) {
        self.repository = repository
    }

    func execute(policy: FetchPolicy, param: SearchTracksParam) async throws -> [Track] {
        guard !param.query.term.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return try await repository.searchTracks(policy: policy, param: param)
    }
}
