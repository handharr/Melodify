import UIKit
import CoreKit

@MainActor
final class HomeCoordinator: Coordinator {
    let navigationController = UINavigationController()
    private let trackRepository: TrackRepositoryProtocol
    private let playlistRepository: PlaylistRepositoryProtocol
    private let analytics: AnalyticsGatewayProtocol

    init(
        trackRepository: TrackRepositoryProtocol,
        playlistRepository: PlaylistRepositoryProtocol,
        analytics: AnalyticsGatewayProtocol
    ) {
        self.trackRepository = trackRepository
        self.playlistRepository = playlistRepository
        self.analytics = analytics
    }

    func start() {
        let useCase = FetchHomeDataUseCase(trackRepository: trackRepository, playlistRepository: playlistRepository)
        let viewModel = HomeViewModel(fetchHomeData: useCase)
        let vc = HomeViewController(viewModel: viewModel)
        vc.delegate = self
        vc.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), tag: 1)
        navigationController.viewControllers = [vc]
    }

    @MainActor func showPlaylistDetail(id: Int) {
        let useCase = PlaylistDetailUseCase(playlistRepository: playlistRepository, trackRepository: trackRepository)
        let viewModel = PlaylistDetailViewModel(playlistId: id, useCase: useCase)
        let vc = PlaylistDetailViewController(viewModel: viewModel)
        navigationController.pushViewController(vc, animated: true)
    }
}

extension HomeCoordinator: HomeDelegate {
    func didSelectPlaylist(_ playlist: PlaylistUIModel) {
        analytics.track(MusicAnalyticsEvent.playlistOpened(id: playlist.id, name: playlist.name))
        showPlaylistDetail(id: playlist.id)
    }
}
