import Foundation
@testable import Melodify

extension PlaylistUIModel {
    static func stub(
        id: Int = 1,
        name: String = "Stub Playlist",
        description: String = "Stub Description",
        trackIds: [Int] = []
    ) -> PlaylistUIModel {
        PlaylistUIModel(id: id, name: name, description: description, trackIds: trackIds)
    }
}
