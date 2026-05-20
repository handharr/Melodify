import Foundation

enum PlaylistMapper {
    static func toDomain(_ dto: PlaylistDTO) -> Playlist {
        Playlist(id: dto.id, name: dto.name, description: dto.description, tracks: [])
    }
}
