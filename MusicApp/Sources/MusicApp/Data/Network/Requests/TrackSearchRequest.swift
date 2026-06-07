import Foundation

struct TrackSearchRequest {
    let query: String
    let offset: Int
    let limit: Int
    let mediaType: String = "music"
}
