import XCTest
@testable import Melodify

@MainActor
final class PlaylistRepositoryTests: XCTestCase {
    var sut: PlaylistRepository!
    var mockDataSource: MockPlaylistDataSource!

    override func setUp() {
        super.setUp()
        mockDataSource = MockPlaylistDataSource()
        sut = PlaylistRepository(remoteDataSource: mockDataSource)
    }

    override func tearDown() {
        sut = nil
        mockDataSource = nil
        super.tearDown()
    }

    func test_fetchPlaylists_mapsDTOsToDomainModels() async throws {
        mockDataSource.fetchResult = .success([
            .stub(id: 1, name: "Chill"),
            .stub(id: 2, name: "Workout")
        ])

        let playlists = try await sut.fetchPlaylists()

        XCTAssertEqual(playlists.count, 2)
        XCTAssertEqual(playlists[0].id, 1)
        XCTAssertEqual(playlists[1].name, "Workout")
    }

    func test_fetchPlaylist_translatesIdToRequest() async throws {
        mockDataSource.fetchOneResult = .success(.stub(id: 5, name: "My Mix", trackIds: [10, 20]))

        let playlist = try await sut.fetchPlaylist(id: 5)

        XCTAssertEqual(mockDataSource.lastFetchOneRequest?.id, 5)
        XCTAssertEqual(playlist.id, 5)
        XCTAssertEqual(playlist.trackIds, [10, 20])
    }

    func test_createPlaylist_translatesParamToRequest() async throws {
        mockDataSource.createResult = .success(.stub(id: 5, name: "New"))
        let param = CreatePlaylistParam(query: CreatePlaylistQuery(name: "New", description: "desc", trackIds: [1, 2, 3]))

        _ = try await sut.createPlaylist(param: param)

        XCTAssertEqual(mockDataSource.lastCreateRequest?.name, "New")
        XCTAssertEqual(mockDataSource.lastCreateRequest?.description, "desc")
        XCTAssertEqual(mockDataSource.lastCreateRequest?.trackIds, [1, 2, 3])
    }

    func test_updatePlaylist_translatesParamToRequest() async throws {
        mockDataSource.updateResult = .success(.stub(id: 7, name: "Updated"))
        let param = UpdatePlaylistParam(
            query: UpdatePlaylistQuery(name: "Updated", description: "new desc"),
            path: UpdatePlaylistPath(id: 7)
        )

        _ = try await sut.updatePlaylist(param: param)

        XCTAssertEqual(mockDataSource.lastUpdateRequest?.id, 7)
        XCTAssertEqual(mockDataSource.lastUpdateRequest?.name, "Updated")
        XCTAssertEqual(mockDataSource.lastUpdateRequest?.description, "new desc")
    }

    func test_fetchPlaylists_dataSourceThrows_propagatesError() async {
        mockDataSource.fetchResult = .failure(APIError.networkError(URLError(.notConnectedToInternet)))

        do {
            _ = try await sut.fetchPlaylists()
            XCTFail("Expected error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}
