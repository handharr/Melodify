import Foundation

@MainActor
final class TrackDetailViewModel {
    private let track: Track

    init(track: Track) {
        self.track = track
    }

    var title: String { track.title }
    var artist: String { track.artist }
    var album: String { track.album }
    var genre: String { track.genre }
    var artworkURL: URL? { track.artworkURL }

    var duration: String {
        let seconds = track.durationMs / 1000
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
