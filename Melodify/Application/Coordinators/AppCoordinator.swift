import UIKit

final class AppCoordinator: DeepLinkHandler {
    private let window: UIWindow
    private var searchCoordinator: SearchCoordinator?
    private var homeCoordinator: HomeCoordinator?
    private var tabBarController: UITabBarController?
    private var deepLinkObserver: Any?

    init(window: UIWindow) {
        self.window = window
    }

    deinit {
        if let observer = deepLinkObserver {
            NotificationCenter.default.removeObserver(observer)
        }
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
        searchCoordinator = search
        homeCoordinator = home

        search.start()
        home.start()

        let tabBar = UITabBarController()
        tabBar.viewControllers = [search.navigationController, home.navigationController]
        tabBarController = tabBar
        window.rootViewController = tabBar
        window.makeKeyAndVisible()

        // Handle deep links arriving from push notification taps (via NotificationCenter)
        deepLinkObserver = NotificationCenter.default.addObserver(
            forName: .handleDeepLink, object: nil, queue: .main
        ) { [weak self] notification in
            guard let link = notification.object as? DeepLink else { return }
            Task { @MainActor [weak self] in self?.handle(link) }
        }
    }

    @MainActor func handle(_ link: DeepLink) {
        switch link {
        case .track(let id):
            tabBarController?.selectedIndex = 0
            searchCoordinator?.showTrackDetail(id: id)
        case .playlist(let id):
            tabBarController?.selectedIndex = 1
            homeCoordinator?.showPlaylistDetail(id: id)
        case .search(let query):
            tabBarController?.selectedIndex = 0
            searchCoordinator?.triggerSearch(query: query)
        }
    }
}
