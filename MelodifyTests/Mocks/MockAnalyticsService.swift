import Foundation
@testable import Melodify

final class MockAnalyticsService: AnalyticsServiceProtocol {
    private(set) var trackedEvents: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        trackedEvents.append(event)
    }
}
