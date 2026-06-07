import Foundation
import Combine

@MainActor
final class HomeViewModel {
    @Published private(set) var feedItems: [HomeFeedItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let fetchHomeData: FetchHomeDataUseCaseProtocol

    init(fetchHomeData: FetchHomeDataUseCaseProtocol) {
        self.fetchHomeData = fetchHomeData
    }

    func loadHome() {
        guard !isLoading else { return }
        isLoading = true

        let request = FetchHomeDataRequest(
            query: FetchHomeDataQuery(
                trackQuery: SearchTracksQuery(term: "top hits", page: 1, limit: 20)
            ),
            policy: .cached
        )

        Task {
            defer { isLoading = false }
            do {
                let data = try await fetchHomeData.execute(request: request)
                let banner = HomeFeedItem.banner(BannerUIModel(title: "Discover Music", subtitle: "Top hits this week"))
                let tracks = data.featuredTracks.map { HomeFeedItem.track(TrackUIModelMapper.toUIModel($0)) }
                let playlists = data.playlists.map { HomeFeedItem.playlist(PlaylistUIModelMapper.toUIModel($0)) }
                feedItems = [banner] + tracks + playlists
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
