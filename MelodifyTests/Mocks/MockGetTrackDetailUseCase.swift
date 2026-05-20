//
//  MockGetTrackDetailUseCase.swift
//  MelodifyTests
//
//  Created by puras.handharmahua@mekari.com on 21/05/26.
//

import Foundation
@testable import Melodify

final class MockGetTrackDetailUseCase: GetTrackDetailUseCaseProtocol {
    var stubbedResult: Result<Track, Error> = .success(Track(id: 0, title: "", artist: "", album: "", artworkURL: nil, previewURL: nil, genre: "", durationMs: 0))
    var calledCount = 1
    var executeFetchPolicy: FetchPolicy?
    var executeParam: GetTrackDetailParam?
    
    func execute(fetchPolicy: FetchPolicy, param: GetTrackDetailParam) async throws -> Track {
        executeFetchPolicy = fetchPolicy
        executeParam = param
        calledCount += 1
        return try stubbedResult.get()
    }
}
