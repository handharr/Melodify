import XCTest
@testable import Melodify

final class PlaylistMapperTests: XCTestCase {

    func test_toDomain_mapsAllFieldsCorrectly() {
        let dto = PlaylistDTO(id: 7, name: "Chill Vibes", description: "Lo-fi beats", trackIds: [1, 2, 3])

        let playlist = PlaylistMapper.toDomain(dto)

        XCTAssertEqual(playlist.id, 7)
        XCTAssertEqual(playlist.name, "Chill Vibes")
        XCTAssertEqual(playlist.description, "Lo-fi beats")
        XCTAssertEqual(playlist.trackIds, [1, 2, 3])
    }

    func test_toDomain_emptyTrackIdsWhenNotPresent() {
        let dto = PlaylistDTO(id: 1, name: "Any", description: "Any")
        XCTAssertTrue(PlaylistMapper.toDomain(dto).trackIds.isEmpty)
    }
}
