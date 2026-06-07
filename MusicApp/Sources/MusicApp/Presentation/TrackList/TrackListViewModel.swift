import Foundation
import Combine
import CoreKit

@MainActor
final class TrackListViewModel: ObservableObject {
    private let searchTracks: SearchTracksUseCaseProtocol
    private let searchSession: SearchSessionServiceProtocol
    private let analytics: AnalyticsGatewayProtocol

    @Published private(set) var tracks: [TrackUIModel] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    init(
        searchTracks: SearchTracksUseCaseProtocol,
        searchSession: SearchSessionServiceProtocol = SearchSessionService(),
        analytics: AnalyticsGatewayProtocol
    ) {
        self.searchTracks = searchTracks
        self.searchSession = searchSession
        self.analytics = analytics
    }

    func search(query: String, genre: String? = nil) {
        tracks = []
        fetch(searchSession.begin(query: query, genre: genre))
    }

    func loadNextPage() {
        guard !isLoading else { return }
        fetch(searchSession.advance())
    }

    private func fetch(_ session: SearchSession) {
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let newTracks = try await searchTracks.execute(request: session.request)
                tracks += newTracks.map(TrackUIModelMapper.toUIModel)
                if session.request.policy.force {
                    analytics.track(MusicAnalyticsEvent.searchPerformed(query: session.request.query.term, resultCount: tracks.count))
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
