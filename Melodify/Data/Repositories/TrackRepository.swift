import Foundation

final class TrackRepository: TrackRepositoryProtocol {
    private let remoteDataSource: TrackDataSourceProtocol

    init(remoteDataSource: TrackDataSourceProtocol = TrackRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
    }

    func searchTracks(policy: FetchPolicy, param: SearchTracksParam) async throws -> [Track] {
        let request = TrackSearchRequest(
            query: param.query.term,
            offset: param.query.offset,
            limit: param.query.limit
        )
        let dtos = try await remoteDataSource.searchTracks(request)
        let tracks = dtos.compactMap { TrackMapper.toDomain($0) }

        guard let genre = param.query.genre else { return tracks }
        return tracks.filter { $0.genre.lowercased() == genre.lowercased() }
    }

    func getTrackDetail(policy: FetchPolicy, param: GetTrackDetailParam) async throws -> Track {
        let request = TrackDetailRequest(id: param.path.id)
        let dto = try await remoteDataSource.getTrackDetail(request)
        guard let track = TrackMapper.toDomain(dto) else { throw APIError.notFound }
        return track
    }
}
