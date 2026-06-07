import Foundation
import CoreKit
import MusicApp
@testable import Melodify

final class MockAnalyticsService: AnalyticsGatewayProtocol, @unchecked Sendable {
    private(set) var trackedEvents: [any AnalyticsEvent] = []

    func track(_ event: any AnalyticsEvent) {
        trackedEvents.append(event)
    }

    var lastMusicEvent: MusicAnalyticsEvent? {
        trackedEvents.compactMap { $0 as? MusicAnalyticsEvent }.last
    }
}
