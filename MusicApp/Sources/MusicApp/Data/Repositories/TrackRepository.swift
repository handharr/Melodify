import Foundation
import CoreKit

final class TrackRepository: TrackRepositoryProtocol, @unchecked Sendable {
    private let remoteDataSource: TrackRemoteDataSourceProtocol
    private let localDataSource: TrackLocalDataSourceProtocol

    init(remoteDataSource: TrackRemoteDataSourceProtocol, localDataSource: TrackLocalDataSourceProtocol) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }

    func searchTracks(policy: FetchPolicy, param: SearchTracksParam) async throws -> [Track] {
        let request = TrackSearchRequest(
            query: param.query.term,
            offset: param.query.offset,
            limit: param.query.limit
        )

        if !policy.force && !policy.allowStale {
            guard let cached = localDataSource.searchTracks(request: request) else { throw APIError.notFound }
            return filtered(cached.compactMap(TrackMapper.toDomain), genre: param.query.genre)
        }

        if !policy.force, let cached = localDataSource.searchTracks(request: request) {
            return filtered(cached.compactMap(TrackMapper.toDomain), genre: param.query.genre)
        }

        let dtos = try await remoteDataSource.searchTracks(request)
        localDataSource.saveSearchTracks(dtos, for: request)
        return filtered(dtos.compactMap(TrackMapper.toDomain), genre: param.query.genre)
    }

    func getTrackDetail(policy: FetchPolicy, param: GetTrackDetailParam) async throws -> Track {
        let request = TrackDetailRequest(id: param.path.id)

        if !policy.force && !policy.allowStale {
            guard let cached = localDataSource.getTrackDetail(request: request),
                  let track = TrackMapper.toDomain(cached) else { throw APIError.notFound }
            return track
        }

        if !policy.force, let cached = localDataSource.getTrackDetail(request: request),
           let track = TrackMapper.toDomain(cached) {
            return track
        }

        let dto = try await remoteDataSource.getTrackDetail(request)
        localDataSource.saveTrackDetail(dto, for: request)
        guard let track = TrackMapper.toDomain(dto) else { throw APIError.notFound }
        return track
    }

    private func filtered(_ tracks: [Track], genre: String?) -> [Track] {
        guard let genre else { return tracks }
        return tracks.filter { $0.genre.lowercased() == genre.lowercased() }
    }
}
