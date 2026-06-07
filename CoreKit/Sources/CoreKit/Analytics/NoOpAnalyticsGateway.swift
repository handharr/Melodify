public final class NoOpAnalyticsGateway: AnalyticsGatewayProtocol {
    public init() {}

    public func track(_ event: any AnalyticsEvent) {}
}
