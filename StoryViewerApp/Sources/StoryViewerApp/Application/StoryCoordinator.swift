import UIKit
import CoreKit

// Composition root — builds the full dependency graph and owns navigation.
// No default concrete args on StoryRepository init; every dependency is injected explicitly.
// Foreground re-entry refresh is handled inside StoryViewController via
// UIApplication.didBecomeActiveNotification (single-screen module — no cross-screen routing needed).
@MainActor
public final class StoryCoordinator {
    private let navigationController: UINavigationController

    public init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    public func start() async {
        let localDataSource = StoryLocalDataSource()
        await localDataSource.seedFromBundle()

        let repository = StoryRepository(
            remoteDataSource: StoryRemoteDataSource(client: APIClient()),
            localDataSource: localDataSource,
            imageDataSource: StoryImageDataSource()
        )

        let orderService = StoryOrderService()

        let viewModel = StoryViewModel(
            fetchStories:  FetchStoriesUseCase(repository: repository),
            loadImage:     LoadStoryImageUseCase(repository: repository),
            prefetchImage: PrefetchStoryImageUseCase(repository: repository),
            orderService:  orderService
        )

        let vc = StoryViewController(viewModel: viewModel)
        vc.title = "Stories"
        navigationController.pushViewController(vc, animated: true)
    }
}
