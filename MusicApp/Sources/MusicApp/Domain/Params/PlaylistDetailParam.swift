struct PlaylistDetailQuery: Equatable, Sendable {}
struct PlaylistDetailPath: Equatable, Sendable { let playlistId: Int }
typealias PlaylistDetailParam = Param<PlaylistDetailQuery, PlaylistDetailPath>
