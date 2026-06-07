// Each mini-app defines its own event enum conforming to this protocol.
// CoreKit stays app-agnostic — it never knows about tracks, messages, or posts.
public protocol AnalyticsEvent: Sendable {
    var name: String { get }
    var params: [String: String] { get }
}
