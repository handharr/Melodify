import CoreKit

struct PlaylistDetailQuery: Equatable, Sendable {}
struct PlaylistDetailPath: Equatable, Sendable { let playlistId: Int }
typealias PlaylistDetailRequest = Request<PlaylistDetailQuery, PlaylistDetailPath>
