import UIKit

final class AppCoordinator {
    private let window: UIWindow
    private var childCoordinators: [AnyObject] = []

    init(window: UIWindow) {
        self.window = window
    }

    func start() {
        let client = APIClient()
        let localDataSource = TrackLocalDataSource()
        let trackRepository = TrackRepository(
            remoteDataSource: TrackRemoteDataSource(client: client),
            localDataSource: localDataSource
        )
        let playlistRepository = PlaylistRepository(remoteDataSource: PlaylistRemoteDataSource(client: client))
        let analytics = ConsoleAnalyticsService()

        let search = SearchCoordinator(trackRepository: trackRepository, analytics: analytics)
        let home = HomeCoordinator(trackRepository: trackRepository, playlistRepository: playlistRepository, analytics: analytics)
        childCoordinators = [search, home]

        search.start()
        home.start()

        let tabBar = UITabBarController()
        tabBar.viewControllers = [search.navigationController, home.navigationController]
        window.rootViewController = tabBar
        window.makeKeyAndVisible()
    }
}
