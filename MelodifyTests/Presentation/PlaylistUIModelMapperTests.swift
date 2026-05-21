import XCTest
@testable import Melodify

final class PlaylistUIModelMapperTests: XCTestCase {

    func test_toUIModel_mapsAllFieldsCorrectly() {
        let playlist = Playlist(id: 7, name: "Chill Vibes", description: "Lo-fi beats", trackIds: [10, 20])

        let uiModel = PlaylistUIModelMapper.toUIModel(playlist)

        XCTAssertEqual(uiModel.id, 7)
        XCTAssertEqual(uiModel.name, "Chill Vibes")
        XCTAssertEqual(uiModel.description, "Lo-fi beats")
        XCTAssertEqual(uiModel.trackIds, [10, 20])
    }
}
