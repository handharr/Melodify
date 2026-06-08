import UIKit
import CoreKit

// Public composition root for the UberEatsApp module.
// The host app creates this, calls start(), then presents navigationController.
// All dependency wiring happens here — no framework DI.
@MainActor
public final class UberEatsCoordinator {
    public let navigationController: UINavigationController

    private let restaurantCoordinator: RestaurantCoordinator

    public init(userID: Int, addressID: Int) {
        let nav = UINavigationController()
        self.navigationController = nav

        let client = APIClient()
        let sseClient = SSEClient()

        restaurantCoordinator = RestaurantCoordinator(
            navigationController: nav,
            userID: userID,
            addressID: addressID,
            restaurantRepository: RestaurantRepository(
                remoteDataSource: RestaurantRemoteDataSource(client: client),
                localDataSource: RestaurantLocalDataSource()
            ),
            dishRepository: DishRepository(
                remoteDataSource: DishRemoteDataSource(client: client),
                localDataSource: DishLocalDataSource()
            ),
            basketRepository: BasketRepository(
                remoteDataSource: BasketRemoteDataSource(client: client),
                localDataSource: BasketLocalDataSource()
            ),
            orderRepository: OrderRepository(
                remoteDataSource: OrderRemoteDataSource(client: client)
            ),
            sseDataSource: OrderSSEDataSource(sseClient: sseClient)
        )
    }

    public func start() {
        restaurantCoordinator.start()
    }
}
