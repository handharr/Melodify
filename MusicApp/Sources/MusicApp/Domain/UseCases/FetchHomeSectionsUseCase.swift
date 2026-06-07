import Foundation

protocol FetchHomeSectionsUseCaseProtocol {
    func execute(request: FetchHomeSectionsRequest) async throws -> [HomeSection]
}

final class FetchHomeSectionsUseCase: FetchHomeSectionsUseCaseProtocol {
    private let repository: TrackRepositoryProtocol

    init(repository: TrackRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: FetchHomeSectionsRequest) async throws -> [HomeSection] {
        let repository = repository
        let genres = request.query.genreQueries.map { $0.genre }

        return try await withThrowingTaskGroup(of: HomeSection.self) { group in
            for (genre, query) in request.query.genreQueries {
                let trackRequest = SearchTracksRequest(query: query, policy: request.policy)
                group.addTask {
                    let tracks = try await repository.searchTracks(request: trackRequest)
                    return HomeSection(genre: genre, tracks: tracks)
                }
            }
            var sections: [HomeSection] = []
            for try await section in group { sections.append(section) }
            return sections.sorted { a, b in
                (genres.firstIndex(of: a.genre) ?? 0) < (genres.firstIndex(of: b.genre) ?? 0)
            }
        }
    }
}
