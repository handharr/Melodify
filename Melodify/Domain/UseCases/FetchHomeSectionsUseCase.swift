import Foundation

protocol FetchHomeSectionsUseCaseProtocol {
    func execute(policy: FetchPolicy, param: FetchHomeSectionsParam) async throws -> [HomeSection]
}

final class FetchHomeSectionsUseCase: FetchHomeSectionsUseCaseProtocol {
    private let repository: TrackRepositoryProtocol

    init(repository: TrackRepositoryProtocol) {
        self.repository = repository
    }

    func execute(policy: FetchPolicy, param: FetchHomeSectionsParam) async throws -> [HomeSection] {
        let repository = repository
        let genres = param.query.genreQueries.map { $0.genre }

        return try await withThrowingTaskGroup(of: HomeSection.self) { group in
            for (genre, query) in param.query.genreQueries {
                let trackParam = SearchTracksParam(query: query)
                group.addTask {
                    let tracks = try await repository.searchTracks(policy: policy, param: trackParam)
                    return HomeSection(genre: genre, tracks: tracks)
                }
            }

            var sections: [HomeSection] = []
            for try await section in group {
                sections.append(section)
            }

            return sections.sorted { a, b in
                (genres.firstIndex(of: a.genre) ?? 0) < (genres.firstIndex(of: b.genre) ?? 0)
            }
        }
    }
}
