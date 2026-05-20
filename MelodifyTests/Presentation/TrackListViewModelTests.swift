import XCTest
@testable import Melodify

@MainActor
final class TrackListViewModelTests: XCTestCase {
    var sut: TrackListViewModel!
    var mockUseCase: MockSearchTracksUseCase!

    override func setUp() {
        super.setUp()
        mockUseCase = MockSearchTracksUseCase()
        sut = TrackListViewModel(searchTracks: mockUseCase)
    }

    override func tearDown() {
        sut = nil
        mockUseCase = nil
        super.tearDown()
    }

    func test_search_success_updatesTracks() async {
        mockUseCase.stubbedResult = .success([.stub(), .stub(id: 2)])
        let expectation = expectation(description: "onUpdate called")
        sut.onUpdate = { expectation.fulfill() }

        sut.search(query: "coldplay")
        await fulfillment(of: [expectation], timeout: 1)

        XCTAssertEqual(sut.tracks.count, 2)
    }

    func test_search_resetsTracksAndPageOnNewSearch() async {
        mockUseCase.stubbedResult = .success([.stub()])

        let first = expectation(description: "first search")
        sut.onUpdate = { first.fulfill() }
        sut.search(query: "coldplay")
        await fulfillment(of: [first], timeout: 1)

        let second = expectation(description: "second search")
        sut.onUpdate = { second.fulfill() }
        sut.search(query: "arctic monkeys")
        await fulfillment(of: [second], timeout: 1)

        XCTAssertEqual(sut.tracks.count, 1)
        XCTAssertEqual(mockUseCase.executedParams.last?.query, "arctic monkeys")
        XCTAssertEqual(mockUseCase.executedParams.last?.page, 1)
    }

    func test_search_failure_callsOnError() async {
        mockUseCase.stubbedResult = .failure(APIError.networkError(URLError(.notConnectedToInternet)))
        let expectation = expectation(description: "onError called")
        sut.onError = { _ in expectation.fulfill() }

        sut.search(query: "coldplay")
        await fulfillment(of: [expectation], timeout: 1)

        XCTAssertTrue(sut.tracks.isEmpty)
    }

    func test_loadNextPage_appendsTracks() async {
        mockUseCase.stubbedResult = .success([.stub()])

        let first = expectation(description: "first page")
        sut.onUpdate = { first.fulfill() }
        sut.search(query: "coldplay")
        await fulfillment(of: [first], timeout: 1)

        let second = expectation(description: "second page")
        sut.onUpdate = { second.fulfill() }
        sut.loadNextPage()
        await fulfillment(of: [second], timeout: 1)

        XCTAssertEqual(sut.tracks.count, 2)
        XCTAssertEqual(mockUseCase.executedParams.last?.page, 2)
    }

    func test_loadNextPage_doesNotFireWhileLoading() async {
        mockUseCase.stubbedResult = .success([.stub()])
        sut.search(query: "coldplay")
        sut.loadNextPage()
        sut.loadNextPage()

        let expectation = expectation(description: "settled")
        sut.onUpdate = { expectation.fulfill() }
        await fulfillment(of: [expectation], timeout: 1)

        XCTAssertEqual(mockUseCase.executedParams.count, 1)
    }
}
