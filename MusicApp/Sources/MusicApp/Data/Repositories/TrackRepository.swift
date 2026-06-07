import Foundation
import CoreKit

final class TrackRepository: TrackRepositoryProtocol, @unchecked Sendable {
    private let remoteDataSource: TrackRemoteDataSourceProtocol
    private let localDataSource: TrackLocalDataSourceProtocol

    init(remoteDataSource: TrackRemoteDataSourceProtocol, localDataSource: TrackLocalDataSourceProtocol) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }

    func searchTracks(request: SearchTracksRequest) async throws -> [Track] {
        let policy = request.policy
        let apiRequest = TrackSearchAPIRequest(
            query: request.query.term,
            offset: request.query.offset,
            limit: request.query.limit
        )

        if !policy.force && !policy.allowStale {
            guard let cached = localDataSource.searchTracks(request: apiRequest) else { throw APIError.notFound }
            return filtered(cached.compactMap(TrackMapper.toDomain), genre: request.query.genre)
        }

        if !policy.force, let cached = localDataSource.searchTracks(request: apiRequest) {
            return filtered(cached.compactMap(TrackMapper.toDomain), genre: request.query.genre)
        }

        let dtos = try await remoteDataSource.searchTracks(apiRequest)
        localDataSource.saveSearchTracks(dtos, for: apiRequest)
        return filtered(dtos.compactMap(TrackMapper.toDomain), genre: request.query.genre)
    }

    func getTrackDetail(request: GetTrackDetailRequest) async throws -> Track {
        let policy = request.policy
        let apiRequest = TrackDetailAPIRequest(id: request.path.id)

        if !policy.force && !policy.allowStale {
            guard let cached = localDataSource.getTrackDetail(request: apiRequest),
                  let track = TrackMapper.toDomain(cached) else { throw APIError.notFound }
            return track
        }

        if !policy.force, let cached = localDataSource.getTrackDetail(request: apiRequest),
           let track = TrackMapper.toDomain(cached) {
            return track
        }

        let dto = try await remoteDataSource.getTrackDetail(apiRequest)
        localDataSource.saveTrackDetail(dto, for: apiRequest)
        guard let track = TrackMapper.toDomain(dto) else { throw APIError.notFound }
        return track
    }

    private func filtered(_ tracks: [Track], genre: String?) -> [Track] {
        guard let genre else { return tracks }
        return tracks.filter { $0.genre.lowercased() == genre.lowercased() }
    }
}
