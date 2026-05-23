import Foundation

// ============================================================
// MARK: - Example 1: Same return type (homogeneous)
// Use case: fetch tracks for multiple genres in parallel
// ============================================================

func fetchSections(
    genres: [String],
    repository: TrackRepositoryProtocol,
    params: [SearchTracksParam]
) async throws -> [HomeSection] {
    try await withThrowingTaskGroup(of: HomeSection.self) { group in
        for (genre, param) in zip(genres, params) {
            group.addTask {
                let tracks = try await repository.searchTracks(policy: .cached, param: param)
                return HomeSection(genre: genre, tracks: tracks)
            }
        }

        // Collect results as they complete (order is non-deterministic)
        var sections: [HomeSection] = []
        for try await section in group {
            sections.append(section)
        }

        // Re-sort to restore original order
        return sections.sorted { a, b in
            (genres.firstIndex(of: a.genre) ?? 0) < (genres.firstIndex(of: b.genre) ?? 0)
        }
    }
}

// ============================================================
// MARK: - Example 2: Different return types (heterogeneous)
// Use case: fetch tracks AND playlists concurrently on home screen
// TaskGroup requires one return type — wrap results in a local enum
// ============================================================

func fetchHomeData(
    trackRepository: TrackRepositoryProtocol,
    playlistRepository: PlaylistRepositoryProtocol,
    trackParam: SearchTracksParam
) async throws -> HomeData {
    enum HomeResult {
        case tracks([Track])
        case playlists([Playlist])
    }

    return try await withThrowingTaskGroup(of: HomeResult.self) { group in
        group.addTask {
            let tracks = try await trackRepository.searchTracks(policy: .cached, param: trackParam)
            return .tracks(tracks)
        }
        group.addTask {
            let playlists = try await playlistRepository.fetchPlaylists()
            return .playlists(playlists)
        }

        var featuredTracks: [Track] = []
        var playlists: [Playlist] = []

        for try await result in group {
            switch result {
            case .tracks(let t):    featuredTracks = t
            case .playlists(let p): playlists = p
            }
        }

        return HomeData(featuredTracks: featuredTracks, playlists: playlists)
    }
}

// ============================================================
// MARK: - Example 3: Partial failure (non-throwing)
// Use case: load what succeeds, skip what fails
// Use withTaskGroup (non-throwing) + optional return type
// ============================================================

func fetchSectionsIgnoringFailures(
    genres: [String],
    repository: TrackRepositoryProtocol,
    params: [SearchTracksParam]
) async -> [HomeSection] {
    await withTaskGroup(of: HomeSection?.self) { group in
        for (genre, param) in zip(genres, params) {
            group.addTask {
                guard let tracks = try? await repository.searchTracks(policy: .cached, param: param) else {
                    return nil // skip failed genre silently
                }
                return HomeSection(genre: genre, tracks: tracks)
            }
        }

        var sections: [HomeSection] = []
        for await section in group {
            if let section { sections.append(section) }
        }
        return sections
    }
}

// ============================================================
// MARK: - Example 4: async let (simpler alternative for fixed ops)
// Use case: exactly 2 concurrent operations — no TaskGroup needed
// ============================================================

func fetchHomeDataAsyncLet(
    trackRepository: TrackRepositoryProtocol,
    playlistRepository: PlaylistRepositoryProtocol,
    trackParam: SearchTracksParam
) async throws -> HomeData {
    async let tracks = trackRepository.searchTracks(policy: .cached, param: trackParam)
    async let playlists = playlistRepository.fetchPlaylists()

    return HomeData(
        featuredTracks: try await tracks,
        playlists: try await playlists
    )
}

// ============================================================
// MARK: - When to use what
//
// async let       → fixed small number of concurrent ops (2-3)
//                   cleaner syntax, no boilerplate
//
// withThrowingTaskGroup → dynamic N items, all same type
//                         OR heterogeneous with enum wrapper
//                         fail-fast: one throw cancels all tasks
//
// withTaskGroup   → same as above but partial failure is ok
//                   use optional return + compactMap pattern
// ============================================================
