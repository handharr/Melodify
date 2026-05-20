import Foundation

struct CreatePlaylistQuery: Sendable {
    let name: String
    let description: String
    let trackIds: [Int]
}

typealias CreatePlaylistParam = Param<CreatePlaylistQuery, Void>
