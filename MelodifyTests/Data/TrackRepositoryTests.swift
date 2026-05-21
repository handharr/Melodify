import XCTest
@testable import Melodify

@MainActor
final class TrackRepositoryTests: XCTestCase {
    var sut: TrackRepository!
    var mockDataSource: MockTrackDataSource!
    var mockLocalDataSource: MockTrackLocalDataSource!

    override func setUp() {
        super.setUp()
        mockDataSource = MockTrackDataSource()
        mockLocalDataSource = MockTrackLocalDataSource()
        sut = TrackRepository(remoteDataSource: mockDataSource, localDataSource: mockLocalDataSource)
    }

    override func tearDown() {
        sut = nil
        mockDataSource = nil
        mockLocalDataSource = nil
        super.tearDown()
    }

    func test_searchTracks_translatesQueryAndOffsetToRequest() async throws {
        mockDataSource.searchResult = .success([])
        let param = SearchTracksParam(query: SearchTracksQuery(term: "coldplay", page: 3, limit: 20))

        _ = try await sut.searchTracks(policy: .fresh, param: param)

        let request = try XCTUnwrap(mockDataSource.lastSearchRequest)
        XCTAssertEqual(request.query, "coldplay")
        XCTAssertEqual(request.offset, 40) // (3-1)*20
        XCTAssertEqual(request.limit, 20)
    }

    func test_searchTracks_withGenreFilter_returnsOnlyMatchingTracks() async throws {
        mockDataSource.searchResult = .success([
            TrackDTO.stub(trackId: 1, primaryGenreName: "Rock"),
            TrackDTO.stub(trackId: 2, primaryGenreName: "Pop")
        ])
        let param = SearchTracksParam(query: SearchTracksQuery(term: "test", genre: "rock"))

        let tracks = try await sut.searchTracks(policy: .fresh, param: param)

        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(tracks.first?.id, 1)
    }

    func test_searchTracks_withoutGenreFilter_returnsAllTracks() async throws {
        mockDataSource.searchResult = .success([TrackDTO.stub(trackId: 1), TrackDTO.stub(trackId: 2)])
        let param = SearchTracksParam(query: SearchTracksQuery(term: "test"))

        let tracks = try await sut.searchTracks(policy: .fresh, param: param)

        XCTAssertEqual(tracks.count, 2)
    }

    func test_searchTracks_filtersOutInvalidDTOs() async throws {
        let invalidDTO = TrackDTO(trackId: nil, trackName: nil, artistName: nil, collectionName: nil, artworkUrl100: nil, previewUrl: nil, primaryGenreName: nil, trackTimeMillis: nil)
        mockDataSource.searchResult = .success([TrackDTO.stub(trackId: 1), invalidDTO])
        let param = SearchTracksParam(query: SearchTracksQuery(term: "test"))

        let tracks = try await sut.searchTracks(policy: .fresh, param: param)

        XCTAssertEqual(tracks.count, 1)
    }

    func test_searchTracks_freshPolicy_alwaysHitsNetworkAndSavesToCache() async throws {
        mockDataSource.searchResult = .success([TrackDTO.stub(trackId: 1)])
        mockLocalDataSource.searchResult = [TrackDTO.stub(trackId: 99)] // cache has different data
        let param = SearchTracksParam(query: SearchTracksQuery(term: "test"))

        let tracks = try await sut.searchTracks(policy: .fresh, param: param)

        XCTAssertEqual(tracks.first?.id, 1)           // network result, not cache
        XCTAssertNotNil(mockLocalDataSource.savedSearchTracks) // saved to cache
    }

    func test_searchTracks_cachedPolicy_returnsCacheWhenAvailable() async throws {
        mockLocalDataSource.searchResult = [TrackDTO.stub(trackId: 99)]
        let param = SearchTracksParam(query: SearchTracksQuery(term: "test"))

        let tracks = try await sut.searchTracks(policy: .cached, param: param)

        XCTAssertEqual(tracks.first?.id, 99)          // cache result
        XCTAssertNil(mockDataSource.lastSearchRequest) // network never called
    }

    func test_searchTracks_cachedPolicy_hitsNetworkOnCacheMiss() async throws {
        mockLocalDataSource.searchResult = nil // no cache
        mockDataSource.searchResult = .success([TrackDTO.stub(trackId: 1)])
        let param = SearchTracksParam(query: SearchTracksQuery(term: "test"))

        let tracks = try await sut.searchTracks(policy: .cached, param: param)

        XCTAssertEqual(tracks.first?.id, 1)           // network fallback
    }

    func test_searchTracks_strictPolicy_throwsOnCacheMiss() async {
        mockLocalDataSource.searchResult = nil
        let param = SearchTracksParam(query: SearchTracksQuery(term: "test"))

        do {
            _ = try await sut.searchTracks(policy: .strict, param: param)
            XCTFail("Expected error on cache miss with strict policy")
        } catch APIError.notFound {
            // expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_getTrackDetail_translatesPathToRequest() async throws {
        mockDataSource.detailResult = .success(TrackDTO.stub(trackId: 99))
        let param = GetTrackDetailParam(path: GetTrackDetailPath(id: 99))

        _ = try await sut.getTrackDetail(policy: .fresh, param: param)

        let request = try XCTUnwrap(mockDataSource.lastDetailRequest)
        XCTAssertEqual(request.id, 99)
    }

    func test_getTrackDetail_invalidDTO_throwsNotFound() async {
        let invalidDTO = TrackDTO(trackId: nil, trackName: nil, artistName: nil, collectionName: nil, artworkUrl100: nil, previewUrl: nil, primaryGenreName: nil, trackTimeMillis: nil)
        mockDataSource.detailResult = .success(invalidDTO)
        let param = GetTrackDetailParam(path: GetTrackDetailPath(id: 1))

        do {
            _ = try await sut.getTrackDetail(policy: .fresh, param: param)
            XCTFail("Expected APIError.notFound")
        } catch APIError.notFound {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
