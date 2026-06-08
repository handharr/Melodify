import Foundation
import Combine

final class ReservationService: ReservationServiceProtocol, @unchecked Sendable {
    private let subject = PassthroughSubject<TimeInterval, Never>()
    private(set) var currentReservation: Reservation?
    private var timer: Timer?

    var timeRemaining: AnyPublisher<TimeInterval, Never> {
        subject.eraseToAnyPublisher()
    }

    func startHold(reservation: Reservation) {
        cancelHold()
        currentReservation = reservation
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let reservation = self.currentReservation else { return }
            let remaining = reservation.expirationTime.timeIntervalSinceNow
            if remaining <= 0 {
                self.subject.send(0)
                self.cancelHold()
            } else {
                self.subject.send(remaining)
            }
        }
    }

    func cancelHold() {
        timer?.invalidate()
        timer = nil
        currentReservation = nil
    }
}
