import Foundation

public struct Request<Query, Path> {
    public let query: Query
    public let path: Path
    public let policy: FetchPolicy

    public init(query: Query, path: Path, policy: FetchPolicy = .fresh) {
        self.query = query
        self.path = path
        self.policy = policy
    }
}

extension Request where Path == Void {
    public init(query: Query, policy: FetchPolicy = .fresh) {
        self.init(query: query, path: (), policy: policy)
    }
}

extension Request where Query == Void {
    public init(path: Path, policy: FetchPolicy = .fresh) {
        self.init(query: (), path: path, policy: policy)
    }
}

extension Request: Sendable where Query: Sendable, Path: Sendable {}
extension Request: Equatable where Query: Equatable, Path: Equatable {}
