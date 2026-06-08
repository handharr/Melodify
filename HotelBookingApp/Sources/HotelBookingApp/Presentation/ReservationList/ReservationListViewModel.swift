import Foundation
import Combine

@MainActor
final class ReservationListViewModel: ObservableObject {

    // MARK: - Output state

    @Published private(set) var reservations: [ReservationListItemUIModel] = []
    @Published private(set) var isLoading: Bool = false

    // MARK: - Private

    private let fetchReservationsUseCase: FetchReservationsUseCaseProtocol

    // MARK: - Init

    init(fetchReservationsUseCase: FetchReservationsUseCaseProtocol) {
        self.fetchReservationsUseCase = fetchReservationsUseCase
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }

        // Offline-only: strict policy reads from local store only
        let request = FetchReservationsRequest(query: (), policy: .strict)
        if let stored = try? await fetchReservationsUseCase.execute(request: request) {
            reservations = stored.map { ReservationListUIModelMapper.toUIModel($0) }
        }
    }
}
