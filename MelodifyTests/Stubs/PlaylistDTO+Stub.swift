import Foundation
@testable import Melodify

extension PlaylistDTO {
    static func stub(
        id: Int = 1,
        name: String = "Stub Playlist",
        description: String = "Stub Description",
        trackIds: [Int] = []
    ) -> PlaylistDTO {
        PlaylistDTO(id: id, name: name, description: description, trackIds: trackIds)
    }
}

extension Array where Element == PlaylistDTO {
    static func stub() -> [PlaylistDTO] {
        [PlaylistDTO.stub()]
    }
}
