import Foundation

enum TrackMapper {
    static func toDomain(_ dto: TrackDTO) -> Track? {
        guard let id = dto.trackId,
              let title = dto.trackName,
              let artist = dto.artistName else { return nil }

        return Track(
            id: id,
            title: title,
            artist: artist,
            album: dto.collectionName ?? "",
            artworkURL: dto.artworkUrl100.flatMap(URL.init),
            previewURL: dto.previewUrl.flatMap(URL.init),
            genre: dto.primaryGenreName ?? "",
            durationMs: dto.trackTimeMillis ?? 0
        )
    }
}
