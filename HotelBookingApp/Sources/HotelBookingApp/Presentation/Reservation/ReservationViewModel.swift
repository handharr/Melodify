import Foundation
import Combine

@MainActor
final class ReservationViewModel: ObservableObject {

    // MARK: - Output state

    @Published private(set) var timeRemainingText: String = ""
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var selectedRoomIds: [String] = []

    // MARK: - Coordinator callback

    var onReserved: ((Reservation) -> Void)?

    // MARK: - Public

    var cancellables = Set<AnyCancellable>()

    // MARK: - Private

    private let hotel: Hotel
    private let createReservationUseCase: CreateReservationUseCaseProtocol
    private let reservationService: ReservationServiceProtocol

    // MARK: - Init

    init(
        hotel: Hotel,
        createReservationUseCase: CreateReservationUseCaseProtocol,
        reservationService: ReservationServiceProtocol
    ) {
        self.hotel = hotel
        self.createReservationUseCase = createReservationUseCase
        self.reservationService = reservationService

        observeTimer()
    }

    // MARK: - Public computed

    var availableRooms: [String] { hotel.rooms.map(\.roomId) }

    // MARK: - Room selection

    func toggleRoom(_ roomId: String) {
        if let index = selectedRoomIds.firstIndex(of: roomId) {
            selectedRoomIds.remove(at: index)
        } else {
            selectedRoomIds.append(roomId)
        }
    }

    // MARK: - Reserve

    func reserve() async {
        guard !selectedRoomIds.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let param = CreateReservationQuery(
                localId: UUID(),
                hotelId: hotel.hotelId,
                roomIds: selectedRoomIds,
                guestCount: 1
            )
            let request = CreateReservationRequest(query: param, policy: .fresh)
            let reservation = try await createReservationUseCase.execute(request: request)
            reservationService.startHold(reservation: reservation)
            onReserved?(reservation)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Timer observation

    private func observeTimer() {
        reservationService.timeRemaining
            .receive(on: RunLoop.main)
            .sink { [weak self] seconds in
                self?.timeRemainingText = Self.format(seconds: seconds)
            }
            .store(in: &cancellables)
    }

    private static func format(seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "00:00" }
        let total = Int(seconds)
        let mm = total / 60
        let ss = total % 60
        return String(format: "%02d:%02d", mm, ss)
    }
}
