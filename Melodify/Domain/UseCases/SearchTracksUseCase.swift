import Foundation

protocol SearchTracksUseCaseProtocol {
    func execute(policy: FetchPolicy, param: SearchTracksParam) async throws -> [Track]
}

final class SearchTracksUseCase: SearchTracksUseCaseProtocol {
    private let repository: TrackRepositoryProtocol

    init(repository: TrackRepositoryProtocol) {
        self.repository = repository
    }

    func execute(policy: FetchPolicy, param: SearchTracksParam) async throws -> [Track] {
        guard !param.query.term.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return try await repository.searchTracks(policy: policy, param: param)
    }
}
