import UIKit
import CoreKit
import MusicApp
import ChatApp
import HotelBookingApp
import MelodifyDesignSystem

final class AppCoordinator: DeepLinkHandler {
    private let window: UIWindow
    private let navigationController = UINavigationController()
    private var homeCoordinator: HomeCoordinator?
    private var musicCoordinator: MusicCoordinator?
    private var chatCoordinator: ChatCoordinator?
    private var hotelBookingCoordinator: HotelBookingCoordinator?
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
        let home = HomeCoordinator()
        home.onAppSelected = { [weak self] id in
            Task { @MainActor [weak self] in self?.push(id) }
        }
        home.start()
        homeCoordinator = home

        navigationController.navigationBar.prefersLargeTitles = true
        navigationController.viewControllers = [home.viewController]
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        deepLinkObserver = NotificationCenter.default.addObserver(
            forName: .handleDeepLink, object: nil, queue: .main
        ) { [weak self] notification in
            guard let link = notification.object as? DeepLink else { return }
            Task { @MainActor [weak self] in self?.handle(link) }
        }
    }

    @MainActor private func push(_ id: AppCardID) {
        switch id {
        case .music:        pushMusicApp()
        case .chat:         pushChatApp()
        case .feed:         pushPlaceholder(title: "Feed", icon: "newspaper.fill")
        case .dsCatalog:    navigationController.pushViewController(DSCatalogViewController(), animated: true)
        case .hotelBooking: pushHotelBookingApp()
        }
    }

    @MainActor private func pushMusicApp() {
        let coordinator = MusicCoordinator(analytics: ConsoleAnalyticsGateway())
        coordinator.start()
        musicCoordinator = coordinator
        navigationController.pushViewController(coordinator.tabBarController, animated: true)
    }

    @MainActor private func pushChatApp() {
        let coordinator = ChatCoordinator(
            webSocketClient: WebSocketClient(),
            navigationController: navigationController
        )
        coordinator.start()
        chatCoordinator = coordinator
    }

    @MainActor private func pushHotelBookingApp() {
        let coordinator = HotelBookingCoordinator()
        coordinator.start()
        hotelBookingCoordinator = coordinator
        navigationController.pushViewController(coordinator.tabBarController, animated: true)
    }

    @MainActor private func pushPlaceholder(title: String, icon: String) {
        let vc = UIViewController()
        vc.title = title
        vc.view.backgroundColor = MDSColor.surface
        let label = UILabel()
        label.text = "\(title) — Coming Soon"
        label.font = Typography.body
        label.textColor = MDSColor.textSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
        ])
        navigationController.pushViewController(vc, animated: true)
    }

    @MainActor func handle(_ link: DeepLink) {
        navigationController.popToRootViewController(animated: false)
        pushMusicApp()
        switch link {
        case .track(let id):
            musicCoordinator?.showTrackDetail(id: id)
        case .playlist(let id):
            musicCoordinator?.showPlaylistDetail(id: id)
        case .search(let query):
            musicCoordinator?.triggerSearch(query: query)
        }
    }
}
