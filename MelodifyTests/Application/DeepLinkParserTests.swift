import XCTest
@testable import Melodify

final class DeepLinkParserTests: XCTestCase {

    func test_parse_trackURL_returnsTrackLink() {
        XCTAssertEqual(DeepLinkParser.parse(URL(string: "melodify://track/123")!), .track(id: 123))
    }

    func test_parse_playlistURL_returnsPlaylistLink() {
        XCTAssertEqual(DeepLinkParser.parse(URL(string: "melodify://playlist/456")!), .playlist(id: 456))
    }

    func test_parse_searchURL_returnsSearchLink() {
        XCTAssertEqual(DeepLinkParser.parse(URL(string: "melodify://search?q=coldplay")!), .search(query: "coldplay"))
    }

    func test_parse_searchURL_multiWordQuery() {
        let url = URL(string: "melodify://search?q=arctic%20monkeys")!
        XCTAssertEqual(DeepLinkParser.parse(url), .search(query: "arctic monkeys"))
    }

    func test_parse_unknownScheme_returnsNil() {
        XCTAssertNil(DeepLinkParser.parse(URL(string: "https://track/123")!))
    }

    func test_parse_unknownHost_returnsNil() {
        XCTAssertNil(DeepLinkParser.parse(URL(string: "melodify://album/99")!))
    }

    func test_parse_trackURL_nonIntId_returnsNil() {
        XCTAssertNil(DeepLinkParser.parse(URL(string: "melodify://track/abc")!))
    }

    func test_parse_playlistURL_nonIntId_returnsNil() {
        XCTAssertNil(DeepLinkParser.parse(URL(string: "melodify://playlist/abc")!))
    }

    func test_parse_searchURL_emptyQuery_returnsNil() {
        XCTAssertNil(DeepLinkParser.parse(URL(string: "melodify://search?q=")!))
    }

    func test_parse_searchURL_missingQueryParam_returnsNil() {
        XCTAssertNil(DeepLinkParser.parse(URL(string: "melodify://search")!))
    }
}
