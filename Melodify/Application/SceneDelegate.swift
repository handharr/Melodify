import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let client = APIClient()
        let trackRepository = TrackRepository(remoteDataSource: TrackRemoteDataSource(client: client))
        let playlistRepository = PlaylistRepository(remoteDataSource: PlaylistRemoteDataSource(client: client))

        let tabBar = UITabBarController()
        tabBar.viewControllers = [
            makeSearchTab(trackRepository: trackRepository),
            makeHomeTab(trackRepository: trackRepository, playlistRepository: playlistRepository)
        ]

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = tabBar
        window?.makeKeyAndVisible()
    }

    private func makeSearchTab(trackRepository: TrackRepositoryProtocol) -> UINavigationController {
        let viewModel = TrackListViewModel(searchTracks: SearchTracksUseCase(repository: trackRepository))
        let vc = TrackListViewController(viewModel: viewModel)
        vc.tabBarItem = UITabBarItem(title: "Search", image: UIImage(systemName: "magnifyingglass"), tag: 0)
        return UINavigationController(rootViewController: vc)
    }

    private func makeHomeTab(trackRepository: TrackRepositoryProtocol, playlistRepository: PlaylistRepositoryProtocol) -> UINavigationController {
        let useCase = FetchHomeDataUseCase(trackRepository: trackRepository, playlistRepository: playlistRepository)
        let viewModel = HomeViewModel(fetchHomeData: useCase)
        let vc = HomeViewController(viewModel: viewModel)
        vc.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), tag: 1)
        return UINavigationController(rootViewController: vc)
    }
}
