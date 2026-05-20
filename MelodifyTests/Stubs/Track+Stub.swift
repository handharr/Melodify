import Foundation
@testable import Melodify

extension Track {
    static func stub(
        id: Int = 1,
        title: String = "Stub Title",
        artist: String = "Stub Artist",
        album: String = "Stub Album",
        genre: String = "Pop",
        durationMs: Int = 210000
    ) -> Track {
        Track(
            id: id,
            title: title,
            artist: artist,
            album: album,
            artworkURL: nil,
            previewURL: nil,
            genre: genre,
            durationMs: durationMs
        )
    }
}
