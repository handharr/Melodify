import Foundation

struct Param<Query, Path> {
    let query: Query
    let path: Path
}

extension Param where Path == Void {
    init(query: Query) {
        self.init(query: query, path: ())
    }
}

extension Param where Query == Void {
    init(path: Path) {
        self.init(query: (), path: path)
    }
}

extension Param: Sendable where Query: Sendable, Path: Sendable {}
extension Param: Equatable where Query: Equatable, Path: Equatable {}
