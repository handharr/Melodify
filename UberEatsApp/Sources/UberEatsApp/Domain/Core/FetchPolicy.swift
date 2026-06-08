import Foundation

struct FetchPolicy: Sendable, Equatable {
    let force: Bool
    let allowStale: Bool

    static let fresh  = FetchPolicy(force: true,  allowStale: false)
    static let cached = FetchPolicy(force: false, allowStale: true)
    static let strict = FetchPolicy(force: false, allowStale: false)
}
