import UIKit

protocol TrackListDelegate: AnyObject {
    func didSelectTrack(_ track: TrackUIModel)
}

final class SearchCoordinator: Coordinator {
    let navigationController = UINavigationController()
    private let trackRepository: TrackRepositoryProtocol
    private let analytics: AnalyticsServiceProtocol

    init(trackRepository: TrackRepositoryProtocol, analytics: AnalyticsServiceProtocol) {
        self.trackRepository = trackRepository
        self.analytics = analytics
    }

    func start() {
        let viewModel = TrackListViewModel(
            searchTracks: SearchTracksUseCase(repository: trackRepository),
            analytics: analytics
        )
        let vc = TrackListViewController(viewModel: viewModel)
        vc.delegate = self
        vc.tabBarItem = UITabBarItem(title: "Search", image: UIImage(systemName: "magnifyingglass"), tag: 0)
        navigationController.viewControllers = [vc]
    }
}

extension SearchCoordinator: TrackListDelegate {
    func didSelectTrack(_ track: TrackUIModel) {
        analytics.track(.trackSelected(id: track.id, title: track.title))
        let useCase = GetTrackDetailUseCase(repository: trackRepository)
        let viewModel = TrackDetailViewModel(trackId: track.id, getTrackDetailUseCase: useCase)
        let vc = TrackDetailViewController(viewModel: viewModel)
        navigationController.pushViewController(vc, animated: true)
    }
}
