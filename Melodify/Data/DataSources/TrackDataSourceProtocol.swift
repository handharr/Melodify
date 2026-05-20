import Foundation

protocol TrackDataSourceProtocol {
    func searchTracks(query: String, offset: Int, limit: Int) async throws -> [TrackDTO]
}
