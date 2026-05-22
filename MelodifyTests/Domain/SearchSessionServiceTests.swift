import XCTest
@testable import Melodify

final class SearchSessionServiceTests: XCTestCase {
    var sut: SearchSessionService!

    override func setUp() {
        super.setUp()
        sut = SearchSessionService()
    }

    func test_begin_returnsFreshPolicyOnPage1() {
        let session = sut.begin(query: "coldplay", genre: nil)

        XCTAssertTrue(session.policy.force)
        XCTAssertEqual(session.param.query.term, "coldplay")
        XCTAssertEqual(session.param.query.page, 1)
        XCTAssertNil(session.param.query.genre)
    }

    func test_begin_forwardsGenre() {
        let session = sut.begin(query: "coldplay", genre: "rock")

        XCTAssertEqual(session.param.query.genre, "rock")
    }

    func test_advance_incrementsPageWithCachedPolicy() {
        _ = sut.begin(query: "coldplay", genre: nil)
        let session = sut.advance()

        XCTAssertFalse(session.policy.force)
        XCTAssertEqual(session.param.query.page, 2)
        XCTAssertEqual(session.param.query.term, "coldplay")
    }

    func test_advance_continuesToIncrement() {
        _ = sut.begin(query: "coldplay", genre: nil)
        _ = sut.advance()
        let session = sut.advance()

        XCTAssertEqual(session.param.query.page, 3)
    }

    func test_begin_resetsStateAfterAdvance() {
        _ = sut.begin(query: "coldplay", genre: nil)
        _ = sut.advance()
        _ = sut.advance()

        let session = sut.begin(query: "arctic monkeys", genre: nil)

        XCTAssertTrue(session.policy.force)
        XCTAssertEqual(session.param.query.page, 1)
        XCTAssertEqual(session.param.query.term, "arctic monkeys")
    }
}
