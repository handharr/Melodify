import UIKit
import CoreKit

@MainActor
final class SearchCoordinator: Coordinator {
    let navigationController = UINavigationController()
    private let trackRepository: TrackRepositoryProtocol
    private let analytics: AnalyticsGatewayProtocol
    private weak var trackListViewModel: TrackListViewModel?

    init(trackRepository: TrackRepositoryProtocol, analytics: AnalyticsGatewayProtocol) {
        self.trackRepository = trackRepository
        self.analytics = analytics
    }

    func start() {
        let viewModel = TrackListViewModel(
            searchTracks: SearchTracksUseCase(repository: trackRepository),
            analytics: analytics
        )
        trackListViewModel = viewModel
        let vc = TrackListViewController(viewModel: viewModel)
        vc.delegate = self
        vc.tabBarItem = UITabBarItem(title: "Search", image: UIImage(systemName: "magnifyingglass"), tag: 0)
        navigationController.viewControllers = [vc]
    }

    @MainActor func showTrackDetail(id: Int) {
        let useCase = GetTrackDetailUseCase(repository: trackRepository)
        let viewModel = TrackDetailViewModel(trackId: id, getTrackDetailUseCase: useCase)
        let vc = TrackDetailViewController(viewModel: viewModel)
        navigationController.pushViewController(vc, animated: true)
    }

    @MainActor func triggerSearch(query: String) {
        navigationController.popToRootViewController(animated: false)
        trackListViewModel?.search(query: query)
    }
}

extension SearchCoordinator: TrackListDelegate {
    func didSelectTrack(_ track: TrackUIModel) {
        analytics.track(MusicAnalyticsEvent.trackSelected(id: track.id, title: track.title))
        let useCase = GetTrackDetailUseCase(repository: trackRepository)
        let viewModel = TrackDetailViewModel(trackId: track.id, getTrackDetailUseCase: useCase)
        let vc = TrackDetailViewController(viewModel: viewModel)
        navigationController.pushViewController(vc, animated: true)
    }
}
