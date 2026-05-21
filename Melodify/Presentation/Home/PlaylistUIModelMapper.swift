import Foundation

enum PlaylistUIModelMapper {
    static func toUIModel(_ playlist: Playlist) -> PlaylistUIModel {
        PlaylistUIModel(
            id: playlist.id,
            name: playlist.name,
            description: playlist.description,
            trackIds: playlist.trackIds
        )
    }
}
