//
//  GetTrackDetailUseCase.swift
//  Melodify
//
//  Created by puras.handharmahua@mekari.com on 21/05/26.
//

import Foundation

protocol GetTrackDetailUseCaseProtocol {
    func execute(fetchPolicy: FetchPolicy, param:  GetTrackDetailParam) async throws -> Track
}

final class GetTrackDetailUseCase: GetTrackDetailUseCaseProtocol {
    private let repository: TrackRepositoryProtocol
    
    init(repository: TrackRepositoryProtocol = TrackRepository()) {
        self.repository = repository
    }
    
    func execute(fetchPolicy: FetchPolicy, param: GetTrackDetailParam) async throws -> Track {
        return try await self.repository.getTrackDetail(policy: fetchPolicy, param: param)
    }
}
