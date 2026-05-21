struct PlaylistDetailQuery: Equatable {}
struct PlaylistDetailPath: Equatable { let playlistId: Int }
typealias PlaylistDetailParam = Param<PlaylistDetailQuery, PlaylistDetailPath>
