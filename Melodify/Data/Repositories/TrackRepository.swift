import Foundation

final class TrackRepository: TrackRepositoryProtocol {
    private let remoteDataSource: TrackDataSourceProtocol

    init(remoteDataSource: TrackDataSourceProtocol = TrackRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
    }

    func searchTracks(policy: FetchPolicy, param: SearchTracksParam) async throws -> [Track] {
        let dtos = try await remoteDataSource.searchTracks(
            query: param.query,
            offset: param.offset,
            limit: param.limit
        )
        let tracks = dtos.compactMap { TrackMapper.toDomain($0) }

        guard let genre = param.genre else { return tracks }
        return tracks.filter { $0.genre.lowercased() == genre.lowercased() }
    }
}
