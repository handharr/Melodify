import UIKit
import CoreKit
import MusicApp
import ChatApp
import HotelBookingApp
import StoryViewerApp
import UberEatsApp
import MelodifyDesignSystem

final class AppCoordinator: DeepLinkHandler {
    private let window: UIWindow
    private let navigationController = UINavigationController()
    private var homeCoordinator: HomeCoordinator?
    private var musicCoordinator: MusicCoordinator?
    private var chatCoordinator: ChatCoordinator?
    private var hotelBookingCoordinator: HotelBookingCoordinator?
    private var storyCoordinator: StoryCoordinator?
    private var uberEatsCoordinator: UberEatsCoordinator?
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
        case .storyViewer:  pushStoryViewerApp()
        case .uberEats:     pushUberEatsApp()
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

    @MainActor private func pushStoryViewerApp() {
        let coordinator = StoryCoordinator(navigationController: navigationController)
        storyCoordinator = coordinator
        Task { await coordinator.start() }
    }

    @MainActor private func pushUberEatsApp() {
        let coordinator = UberEatsCoordinator(userID: 1, addressID: 1)
        coordinator.start()
        uberEatsCoordinator = coordinator
        navigationController.pushViewController(coordinator.navigationController, animated: true)
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
