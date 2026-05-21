final class ConsoleAnalyticsService: AnalyticsServiceProtocol {
    func track(_ event: AnalyticsEvent) {
        print("[Analytics] \(event)")
    }
}
