import Foundation
import Combine

@MainActor
final class TrackListViewModel: ObservableObject {
    private let searchTracks: SearchTracksUseCaseProtocol
    private let analytics: AnalyticsServiceProtocol

    @Published private(set) var tracks: [TrackUIModel] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String? = nil

    private var currentQuery: String = ""
    private var currentPage: Int = 1
    private var currentGenre: String? = nil

    init(searchTracks: SearchTracksUseCaseProtocol, analytics: AnalyticsServiceProtocol) {
        self.searchTracks = searchTracks
        self.analytics = analytics
    }

    func search(query: String, genre: String? = nil) {
        currentQuery = query
        currentPage = 1
        currentGenre = genre
        tracks = []
        fetch(policy: .fresh)
    }

    func loadNextPage() {
        guard !isLoading else { return }
        currentPage += 1
        fetch(policy: .cached)
    }

    private func fetch(policy: FetchPolicy) {
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let param = SearchTracksParam(
                    query: SearchTracksQuery(
                        term: currentQuery,
                        page: currentPage,
                        genre: currentGenre
                    )
                )
                let newTracks = try await searchTracks.execute(policy: policy, param: param)
                tracks += newTracks.map(TrackUIModelMapper.toUIModel)
                if policy.force {
                    analytics.track(.searchPerformed(query: currentQuery, resultCount: tracks.count))
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
