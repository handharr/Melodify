public protocol AnalyticsGatewayProtocol: AnyObject, Sendable {
    func track(_ event: any AnalyticsEvent)
}
