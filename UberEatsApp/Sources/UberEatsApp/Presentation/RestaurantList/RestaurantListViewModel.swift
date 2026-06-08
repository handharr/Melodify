import Foundation
import Combine

@MainActor
final class RestaurantListViewModel {
    @Published private(set) var restaurants: [RestaurantUIModel] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let addressID: Int
    private let fetchRestaurants: FetchRestaurantsUseCaseProtocol

    var onSelectRestaurant: ((RestaurantUIModel) -> Void)?

    init(addressID: Int, fetchRestaurants: FetchRestaurantsUseCaseProtocol) {
        self.addressID = addressID
        self.fetchRestaurants = fetchRestaurants
    }

    func load() {
        Task {
            defer { isLoading = false }
            isLoading = true

            // Phase 1 — cache (instant render)
            if let cached = try? await fetchRestaurants.execute(
                request: FetchRestaurantsRequest(path: FetchRestaurantsPath(addressID: addressID), policy: .strict)
            ) {
                restaurants = cached.map(RestaurantUIModel.from)
            }

            // Phase 2 — network (background refresh)
            do {
                let fresh = try await fetchRestaurants.execute(
                    request: FetchRestaurantsRequest(path: FetchRestaurantsPath(addressID: addressID), policy: .fresh)
                )
                restaurants = fresh.map(RestaurantUIModel.from)
            } catch {
                if restaurants.isEmpty { errorMessage = error.localizedDescription }
            }
        }
    }

    func selectRestaurant(_ model: RestaurantUIModel) {
        onSelectRestaurant?(model)
    }
}
