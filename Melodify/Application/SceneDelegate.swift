import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var appCoordinator: AppCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        let coordinator = AppCoordinator(window: window)
        appCoordinator = coordinator
        coordinator.start()

        // Deep link from cold launch (app was not running when URL was opened)
        if let urlContext = connectionOptions.urlContexts.first,
           let link = DeepLinkParser.parse(urlContext.url) {
            coordinator.handle(link)
        }
    }

    // Deep link while app is already running
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url,
              let link = DeepLinkParser.parse(url) else { return }
        appCoordinator?.handle(link)
    }
}
