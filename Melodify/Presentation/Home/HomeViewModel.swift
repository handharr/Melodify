import Foundation

@MainActor
final class HomeViewModel {
    private let fetchHomeData: FetchHomeDataUseCaseProtocol

    private(set) var featuredTracks: [Track] = []
    private(set) var playlists: [Playlist] = []
    private(set) var isLoading: Bool = false

    var onUpdate: (() -> Void)?
    var onError: ((String) -> Void)?

    init(fetchHomeData: FetchHomeDataUseCaseProtocol) {
        self.fetchHomeData = fetchHomeData
    }

    func loadHome() {
        guard !isLoading else { return }
        isLoading = true

        let param = FetchHomeDataParam(
            query: FetchHomeDataQuery(
                trackQuery: SearchTracksQuery(term: "top hits", page: 1, limit: 20)
            )
        )

        Task {
            defer { isLoading = false }
            do {
                let data = try await fetchHomeData.execute(policy: .cached, param: param)
                featuredTracks = data.featuredTracks
                playlists = data.playlists
                onUpdate?()
            } catch {
                onError?(error.localizedDescription)
            }
        }
    }
}
