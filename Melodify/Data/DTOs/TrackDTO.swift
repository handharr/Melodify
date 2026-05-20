import Foundation

struct iTunesSearchResponse: Decodable {
    let results: [TrackDTO]
}

struct TrackDTO: Decodable {
    let trackId: Int?
    let trackName: String?
    let artistName: String?
    let collectionName: String?
    let artworkUrl100: String?
    let previewUrl: String?
    let primaryGenreName: String?
    let trackTimeMillis: Int?

}
