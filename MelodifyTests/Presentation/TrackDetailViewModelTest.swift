//
//  TrackDetailViewModelTest.swift
//  MelodifyTests
//
//  Created by puras.handharmahua@mekari.com on 21/05/26.
//

import XCTest
@testable import Melodify
import Combine

@MainActor
final class TrackDetailViewModelTest: XCTestCase {
    var sut: TrackDetailViewModel!
    var getTrackDetailUseCaseMock: MockGetTrackDetailUseCase!
    var cancellable: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        getTrackDetailUseCaseMock = MockGetTrackDetailUseCase()
        sut = TrackDetailViewModel(track: Track(id: 1, title: "Title", artist: "Artist", album: "Album", artworkURL: nil, previewURL: nil, genre: "Genre", durationMs: 300), getTrackDetailUseCase: getTrackDetailUseCaseMock)
        cancellable = []
    }
    
    override func tearDown() {
        sut = nil
        getTrackDetailUseCaseMock = nil
        super.tearDown()
    }
    
    func test_load_success() async {
        getTrackDetailUseCaseMock.stubbedResult = .success(Track(id: 1, title: "Title", artist: "Artist", album: "Album", artworkURL: nil, previewURL: nil, genre: "Genre", durationMs: 300))
        
        let expectation = expectation(description: "Test")
        sut.$track
            .dropFirst()
            .compactMap({ $0 })
            .sink(receiveValue: { _ in expectation.fulfill() })
            .store(in: &cancellable)
        
        sut.load()
        await fulfillment(of: [expectation], timeout: 2)
        
        XCTAssertEqual(sut.track?.id, 1)
    }
}
