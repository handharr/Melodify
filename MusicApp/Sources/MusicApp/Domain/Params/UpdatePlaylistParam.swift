import Foundation

struct UpdatePlaylistQuery: Sendable {
    let name: String
    let description: String
}

struct UpdatePlaylistPath: Sendable {
    let id: Int
}

typealias UpdatePlaylistParam = Param<UpdatePlaylistQuery, UpdatePlaylistPath>
