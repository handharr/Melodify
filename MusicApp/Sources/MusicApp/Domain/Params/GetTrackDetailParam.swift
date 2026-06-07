import Foundation

struct GetTrackDetailPath: Sendable {
    let id: Int
}

typealias GetTrackDetailParam = Param<Void, GetTrackDetailPath>
