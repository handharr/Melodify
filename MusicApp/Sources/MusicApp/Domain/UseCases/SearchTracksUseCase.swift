import Foundation

protocol SearchTracksUseCaseProtocol: Sendable {
    func execute(request: SearchTracksRequest) async throws -> [Track]
}

final class SearchTracksUseCase: SearchTracksUseCaseProtocol, @unchecked Sendable {
    private let repository: TrackRepositoryProtocol

    init(repository: TrackRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: SearchTracksRequest) async throws -> [Track] {
        guard !request.query.term.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return try await repository.searchTracks(request: request)
    }
}
