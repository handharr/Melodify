import Foundation

struct TrackSearchAPIRequest {
    let query: String
    let offset: Int
    let limit: Int
    let mediaType: String = "music"
}
