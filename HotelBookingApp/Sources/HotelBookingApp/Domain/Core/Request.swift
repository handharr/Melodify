struct Request<Query, Path> {
    let query: Query
    let path: Path
    let policy: FetchPolicy
}

extension Request where Path == Void {
    init(query: Query, policy: FetchPolicy = .fresh) {
        self.init(query: query, path: (), policy: policy)
    }
}

extension Request where Query == Void {
    init(path: Path, policy: FetchPolicy = .fresh) {
        self.init(query: (), path: path, policy: policy)
    }
}

extension Request: Sendable where Query: Sendable, Path: Sendable {}
extension Request: Equatable where Query: Equatable, Path: Equatable {}
