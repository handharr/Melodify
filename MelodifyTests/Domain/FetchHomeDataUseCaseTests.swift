import XCTest
@testable import Melodify

@MainActor
final class FetchHomeDataUseCaseTests: XCTestCase {
    var sut: FetchHomeDataUseCase!
    var mockTrackRepository: MockTrackRepository!
    var mockPlaylistRepository: MockPlaylistRepository!

    override func setUp() {
        super.setUp()
        mockTrackRepository = MockTrackRepository()
        mockPlaylistRepository = MockPlaylistRepository()
        sut = FetchHomeDataUseCase(trackRepository: mockTrackRepository, playlistRepository: mockPlaylistRepository)
    }

    override func tearDown() {
        sut = nil
        mockTrackRepository = nil
        mockPlaylistRepository = nil
        super.tearDown()
    }

    func test_execute_success_returnsCombinedData() async throws {
        mockTrackRepository.stubbedResult = .success([.stub(id: 1), .stub(id: 2)])
        mockPlaylistRepository.fetchResult = .success([.stub(id: 10)])

        let param = FetchHomeDataParam(query: FetchHomeDataQuery(trackQuery: SearchTracksQuery(term: "top hits")))
        let result = try await sut.execute(policy: .fresh, param: param)

        XCTAssertEqual(result.featuredTracks.count, 2)
        XCTAssertEqual(result.playlists.count, 1)
        XCTAssertEqual(result.playlists.first?.id, 10)
    }

    func test_execute_trackRepositoryThrows_propagatesError() async {
        mockTrackRepository.stubbedResult = .failure(APIError.networkError(URLError(.notConnectedToInternet)))
        mockPlaylistRepository.fetchResult = .success([])

        let param = FetchHomeDataParam(query: FetchHomeDataQuery(trackQuery: SearchTracksQuery(term: "hits")))
        do {
            _ = try await sut.execute(policy: .fresh, param: param)
            XCTFail("Expected error")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func test_execute_playlistRepositoryThrows_propagatesError() async {
        mockTrackRepository.stubbedResult = .success([])
        mockPlaylistRepository.fetchResult = .failure(APIError.networkError(URLError(.notConnectedToInternet)))

        let param = FetchHomeDataParam(query: FetchHomeDataQuery(trackQuery: SearchTracksQuery(term: "hits")))
        do {
            _ = try await sut.execute(policy: .fresh, param: param)
            XCTFail("Expected error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}
