import Foundation
import CoreKit

struct GetTrackDetailPath: Sendable {
    let id: Int
}

typealias GetTrackDetailRequest = Request<Void, GetTrackDetailPath>
