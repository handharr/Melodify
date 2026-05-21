import XCTest
import Combine
@testable import Melodify

@MainActor
final class PlaylistDetailViewModelTests: XCTestCase {
    var sut: PlaylistDetailViewModel!
    var mockUseCase: MockPlaylistDetailUseCase!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockUseCase = MockPlaylistDetailUseCase()
        sut = PlaylistDetailViewModel(playlistId: 42, useCase: mockUseCase)
        cancellables = []
    }

    override func tearDown() {
        sut = nil
        mockUseCase = nil
        cancellables = nil
        super.tearDown()
    }

    func test_load_success_populatesDetail() async {
        let tracks: [Track] = [.stub(id: 1, title: "Yellow"), .stub(id: 2, title: "Clocks")]
        mockUseCase.stubbedResult = .success(PlaylistDetail(playlist: .stub(id: 42, name: "My Mix"), tracks: tracks))

        let expectation = expectation(description: "detail populated")
        sut.$detail
            .compactMap { $0 }
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        sut.load()
        await fulfillment(of: [expectation], timeout: 1)

        XCTAssertEqual(sut.detail?.name, "My Mix")
        XCTAssertEqual(sut.detail?.tracks.count, 2)
        XCTAssertEqual(sut.detail?.tracks.first?.title, "Yellow")
        XCTAssertFalse(sut.isLoading)
    }

    func test_load_passesCorrectPlaylistIdToUseCase() async {
        let expectation = expectation(description: "executed")
        sut.$detail
            .compactMap { $0 }
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        sut.load()
        await fulfillment(of: [expectation], timeout: 1)

        XCTAssertEqual(mockUseCase.executedParam?.path.playlistId, 42)
    }

    func test_load_failure_setsErrorMessage() async {
        mockUseCase.stubbedResult = .failure(APIError.networkError(URLError(.notConnectedToInternet)))

        let expectation = expectation(description: "errorMessage set")
        sut.$errorMessage
            .compactMap { $0 }
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        sut.load()
        await fulfillment(of: [expectation], timeout: 1)

        XCTAssertNil(sut.detail)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }
}
