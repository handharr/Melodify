import Foundation

struct GetTrackDetailPath: Sendable {
    let id: Int
}

typealias GetTrackDetailRequest = Request<Void, GetTrackDetailPath>
