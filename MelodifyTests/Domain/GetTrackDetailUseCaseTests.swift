import XCTest
@testable import Melodify


final class GetTrackDetailUseCaseTests: XCTestCase {
    var sut: GetTrackDetailUseCase!
    var mockRepository: MockTrackRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockTrackRepository()
        sut = GetTrackDetailUseCase(repository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    func test_execute_success_returnsTrack() async throws {
        mockRepository.getTrackDetailStubbedResult = .success(Track(id: 1, title: "Title", artist: "Artist", album: "Album", artworkURL: nil, previewURL: nil, genre: "Genre", durationMs: 300))
        let result = try await sut.execute(fetchPolicy: .fresh, param: GetTrackDetailParam(path: GetTrackDetailPath(id: 1)))
        let id = result.id
        XCTAssertEqual(id, 1)
    }

    func test_execute_failure_propagatesError() async {
        mockRepository.getTrackDetailStubbedResult = .failure(APIError.networkError(URLError(.notConnectedToInternet)))
        do {
            _ = try await sut.execute(fetchPolicy: .fresh, param: GetTrackDetailParam(path: GetTrackDetailPath(id: 1)))
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}
