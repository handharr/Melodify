import Foundation

final class TrackRepository: TrackRepositoryProtocol {
    private let remoteDataSource: TrackDataSourceProtocol

    init(remoteDataSource: TrackDataSourceProtocol = TrackRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
    }

    func searchTracks(policy: FetchPolicy, param: SearchTracksParam) async throws -> [Track] {
        let dtos = try await remoteDataSource.searchTracks(
            query: param.query.term,
            offset: param.query.offset,
            limit: param.query.limit
        )
        let tracks = dtos.compactMap { TrackMapper.toDomain($0) }

        guard let genre = param.query.genre else { return tracks }
        return tracks.filter { $0.genre.lowercased() == genre.lowercased() }
    }
}
