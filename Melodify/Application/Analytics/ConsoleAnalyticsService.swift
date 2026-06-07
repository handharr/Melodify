import CoreKit

final class ConsoleAnalyticsService: AnalyticsGatewayProtocol {
    func track(_ event: any AnalyticsEvent) {
        print("[Analytics] \(event.name) \(event.params)")
    }
}
