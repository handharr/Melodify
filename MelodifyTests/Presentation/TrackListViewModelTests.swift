import XCTest
import Combine
@testable import Melodify

@MainActor
final class TrackListViewModelTests: XCTestCase {
    var sut: TrackListViewModel!
    var mockUseCase: MockSearchTracksUseCase!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockUseCase = MockSearchTracksUseCase()
        sut = TrackListViewModel(searchTracks: mockUseCase)
        cancellables = []
    }

    override func tearDown() {
        sut = nil
        mockUseCase = nil
        cancellables = nil
        super.tearDown()
    }

    func test_search_success_updatesTracks() async {
        mockUseCase.stubbedResult = .success([.stub(), .stub(id: 2)])
        let expectation = expectation(description: "tracks updated")
        sut.$tracks
            .filter { !$0.isEmpty }
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        sut.search(query: "coldplay")
        await fulfillment(of: [expectation], timeout: 1)

        XCTAssertEqual(sut.tracks.count, 2)
    }

    func test_search_resetsTracksAndPageOnNewSearch() async {
        mockUseCase.stubbedResult = .success([.stub()])

        let first = expectation(description: "first search")
        sut.$tracks.filter { !$0.isEmpty }.first()
            .sink { _ in first.fulfill() }
            .store(in: &cancellables)
        sut.search(query: "coldplay")
        await fulfillment(of: [first], timeout: 1)

        let second = expectation(description: "second search")
        sut.$tracks.filter { !$0.isEmpty }.dropFirst()
            .sink { _ in second.fulfill() }
            .store(in: &cancellables)
        sut.search(query: "arctic monkeys")
        await fulfillment(of: [second], timeout: 1)

        XCTAssertEqual(sut.tracks.count, 1)
        XCTAssertEqual(mockUseCase.executedParams.last?.query.term, "arctic monkeys")
        XCTAssertEqual(mockUseCase.executedParams.last?.query.page, 1)
    }

    func test_search_failure_setsErrorMessage() async {
        mockUseCase.stubbedResult = .failure(APIError.networkError(URLError(.notConnectedToInternet)))
        let expectation = expectation(description: "errorMessage set")
        sut.$errorMessage
            .compactMap { $0 }
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        sut.search(query: "coldplay")
        await fulfillment(of: [expectation], timeout: 1)

        XCTAssertTrue(sut.tracks.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
    }

    func test_loadNextPage_appendsTracks() async {
        mockUseCase.stubbedResult = .success([.stub()])

        let first = expectation(description: "first page")
        sut.$tracks.filter { !$0.isEmpty }.first()
            .sink { _ in first.fulfill() }
            .store(in: &cancellables)
        sut.search(query: "coldplay")
        await fulfillment(of: [first], timeout: 1)

        let second = expectation(description: "second page")
        sut.$tracks.filter { $0.count == 2 }
            .sink { _ in second.fulfill() }
            .store(in: &cancellables)
        sut.loadNextPage()
        await fulfillment(of: [second], timeout: 1)

        XCTAssertEqual(sut.tracks.count, 2)
        XCTAssertEqual(mockUseCase.executedParams.last?.query.page, 2)
    }

    func test_loadNextPage_doesNotFireWhileLoading() async {
        mockUseCase.stubbedResult = .success([.stub()])

        let expectation = expectation(description: "settled")
        sut.$isLoading
            .filter { !$0 }
            .dropFirst() // skip initial false, wait for true→false transition
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        sut.search(query: "coldplay")
        sut.loadNextPage()
        sut.loadNextPage()
        await fulfillment(of: [expectation], timeout: 1)

        XCTAssertEqual(mockUseCase.executedParams.count, 1)
    }
}
