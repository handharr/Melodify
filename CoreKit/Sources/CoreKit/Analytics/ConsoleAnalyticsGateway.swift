public final class ConsoleAnalyticsGateway: AnalyticsGatewayProtocol {
    public init() {}

    public func track(_ event: any AnalyticsEvent) {
        print("[Analytics] \(event.name) \(event.params)")
    }
}
