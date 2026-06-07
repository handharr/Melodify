import UIKit
import CoreKit
import MusicApp

final class AppCoordinator: DeepLinkHandler {
    private let window: UIWindow
    private var musicCoordinator: MusicCoordinator?
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
        let analytics = ConsoleAnalyticsGateway()

        let music = MusicCoordinator(analytics: analytics)
        music.start()
        musicCoordinator = music

        let tabBar = UITabBarController()
        tabBar.viewControllers = [
            music.searchNavigationController,
            music.homeNavigationController,
            makePlaceholder(title: "Chat", icon: "message", tag: 2),
            makePlaceholder(title: "Feed", icon: "newspaper", tag: 3)
        ]
        tabBarController = tabBar
        window.rootViewController = tabBar
        window.makeKeyAndVisible()

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
            musicCoordinator?.showTrackDetail(id: id)
        case .playlist(let id):
            tabBarController?.selectedIndex = 1
            musicCoordinator?.showPlaylistDetail(id: id)
        case .search(let query):
            tabBarController?.selectedIndex = 0
            musicCoordinator?.triggerSearch(query: query)
        }
    }

    private func makePlaceholder(title: String, icon: String, tag: Int) -> UINavigationController {
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = "\(title) — Coming Soon"
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor)
        ])
        let nav = UINavigationController(rootViewController: vc)
        nav.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: icon), tag: tag)
        return nav
    }
}
