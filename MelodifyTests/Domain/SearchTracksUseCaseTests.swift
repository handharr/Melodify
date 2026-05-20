import XCTest
@testable import Melodify

final class SearchTracksUseCaseTests: XCTestCase {
    var sut: SearchTracksUseCase!
    var mockRepository: MockTrackRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockTrackRepository()
        sut = SearchTracksUseCase(repository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    func test_execute_emptyQuery_returnsEmptyWithoutCallingRepository() async throws {
        let result = try await sut.execute(policy: .fresh, param: SearchTracksParam(query: ""))
        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(mockRepository.callCount, 0)
    }

    func test_execute_whitespaceQuery_returnsEmptyWithoutCallingRepository() async throws {
        let result = try await sut.execute(policy: .fresh, param: SearchTracksParam(query: "   "))
        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(mockRepository.callCount, 0)
    }

    func test_execute_validQuery_callsRepository() async throws {
        mockRepository.stubbedResult = .success([.stub(), .stub(id: 2)])
        let result = try await sut.execute(policy: .fresh, param: SearchTracksParam(query: "coldplay"))
        XCTAssertEqual(mockRepository.callCount, 1)
        XCTAssertEqual(result.count, 2)
    }

    func test_execute_passesParamToRepository() async throws {
        mockRepository.stubbedResult = .success([])
        let param = SearchTracksParam(query: "coldplay", page: 2, genre: "Rock")
        _ = try await sut.execute(policy: .cached, param: param)
        XCTAssertEqual(mockRepository.receivedParam?.query, "coldplay")
        XCTAssertEqual(mockRepository.receivedParam?.page, 2)
        XCTAssertEqual(mockRepository.receivedParam?.genre, "Rock")
    }

    func test_execute_repositoryThrows_propagatesError() async {
        mockRepository.stubbedResult = .failure(APIError.networkError(URLError(.notConnectedToInternet)))
        do {
            _ = try await sut.execute(policy: .fresh, param: SearchTracksParam(query: "coldplay"))
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}
