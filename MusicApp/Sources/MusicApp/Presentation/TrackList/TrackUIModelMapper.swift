import Foundation

enum TrackUIModelMapper {
    static func toUIModel(_ track: Track) -> TrackUIModel {
        let seconds = track.durationMs / 1000
        return TrackUIModel(
            id: track.id,
            title: track.title,
            artist: track.artist,
            duration: String(format: "%d:%02d", seconds / 60, seconds % 60),
            artworkURL: track.artworkURL
        )
    }
}
