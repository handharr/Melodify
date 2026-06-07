import Foundation

enum TrackDetailUIModelMapper {
    static func toUIModel(_ track: Track) -> TrackDetailUIModel {
        let seconds = track.durationMs / 1000
        return TrackDetailUIModel(
            title: track.title,
            artist: track.artist,
            album: track.album,
            genre: track.genre,
            duration: String(format: "%d:%02d", seconds / 60, seconds % 60),
            artworkURL: track.artworkURL
        )
    }
}
