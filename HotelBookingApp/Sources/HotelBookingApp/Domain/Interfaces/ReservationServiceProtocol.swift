import Combine
import Foundation

protocol ReservationServiceProtocol: AnyObject, Sendable {
    var timeRemaining: AnyPublisher<TimeInterval, Never> { get }
    var currentReservation: Reservation? { get }
    func startHold(reservation: Reservation)
    func cancelHold()
}
