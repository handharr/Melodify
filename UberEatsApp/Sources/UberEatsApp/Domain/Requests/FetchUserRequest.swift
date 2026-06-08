import Foundation

typealias FetchUserRequest = Request<Void, FetchUserPath>

struct FetchUserPath: Sendable, Equatable {
    let userID: Int
}
