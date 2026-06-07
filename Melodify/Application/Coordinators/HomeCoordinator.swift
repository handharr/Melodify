import UIKit

@MainActor
final class HomeCoordinator {
    private(set) var viewController: HomeViewController
    var onAppSelected: ((AppCardID) -> Void)?

    init() {
        viewController = HomeViewController()
    }

    func start() {
        viewController.onCardTapped = { [weak self] id in
            self?.onAppSelected?(id)
        }
    }
}
