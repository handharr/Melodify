import XCTest
@testable import Melodify

@MainActor
final class PlaylistDetailUseCaseTests: XCTestCase {
    var sut: PlaylistDetailUseCase!
    var mockPlaylistRepo: MockPlaylistRepository!
    var mockTrackRepo: MockTrackRepository!

    override func setUp() {
        super.setUp()
        mockPlaylistRepo = MockPlaylistRepository()
        mockTrackRepo = MockTrackRepository()
        sut = PlaylistDetailUseCase(playlistRepository: mockPlaylistRepo, trackRepository: mockTrackRepo)
    }

    override func tearDown() {
        sut = nil
        mockPlaylistRepo = nil
        mockTrackRepo = nil
        super.tearDown()
    }

    func test_execute_emptyTrackIds_returnsPlaylistWithNoTracks() async throws {
        mockPlaylistRepo.fetchOneResult = .success(.stub(id: 1, trackIds: []))
        let param = PlaylistDetailParam(query: PlaylistDetailQuery(), path: PlaylistDetailPath(playlistId: 1))

        let result = try await sut.execute(policy: .fresh, param: param)

        XCTAssertEqual(result.playlist.id, 1)
        XCTAssertTrue(result.tracks.isEmpty)
    }

    func test_execute_withTrackIds_fetchesEachConcurrently() async throws {
        mockPlaylistRepo.fetchOneResult = .success(.stub(id: 1, trackIds: [10, 20]))
        mockTrackRepo.getTrackDetailStubbedResult = .success(.stub(id: 10))
        let param = PlaylistDetailParam(query: PlaylistDetailQuery(), path: PlaylistDetailPath(playlistId: 1))

        let result = try await sut.execute(policy: .fresh, param: param)

        XCTAssertEqual(result.tracks.count, 2)
    }

    func test_execute_playlistRepositoryThrows_propagatesError() async {
        mockPlaylistRepo.fetchOneResult = .failure(APIError.networkError(URLError(.notConnectedToInternet)))
        let param = PlaylistDetailParam(query: PlaylistDetailQuery(), path: PlaylistDetailPath(playlistId: 1))

        do {
            _ = try await sut.execute(policy: .fresh, param: param)
            XCTFail("Expected error")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func test_execute_trackRepositoryThrows_propagatesError() async {
        mockPlaylistRepo.fetchOneResult = .success(.stub(id: 1, trackIds: [10]))
        mockTrackRepo.getTrackDetailStubbedResult = .failure(APIError.notFound)
        let param = PlaylistDetailParam(query: PlaylistDetailQuery(), path: PlaylistDetailPath(playlistId: 1))

        do {
            _ = try await sut.execute(policy: .fresh, param: param)
            XCTFail("Expected error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}
