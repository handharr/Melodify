import Foundation

public struct FetchPolicy: Sendable, Equatable {
    public let force: Bool
    public let allowStale: Bool

    public static let fresh  = FetchPolicy(force: true,  allowStale: false)
    public static let cached = FetchPolicy(force: false, allowStale: true)
    public static let strict = FetchPolicy(force: false, allowStale: false)
}
