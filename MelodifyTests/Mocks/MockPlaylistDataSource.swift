import Foundation
@testable import Melodify

final class MockPlaylistDataSource: PlaylistRemoteDataSourceProtocol {
    var fetchResult: Result<[PlaylistDTO], Error> = .success([])
    var fetchOneResult: Result<PlaylistDTO, Error> = .success(.stub())
    var createResult: Result<PlaylistDTO, Error> = .success(.stub())
    var updateResult: Result<PlaylistDTO, Error> = .success(.stub())

    private(set) var lastFetchRequest: FetchPlaylistsRequest?
    private(set) var lastFetchOneRequest: FetchPlaylistRequest?
    private(set) var lastCreateRequest: CreatePlaylistRequest?
    private(set) var lastUpdateRequest: UpdatePlaylistRequest?

    func fetchPlaylists(_ request: FetchPlaylistsRequest) async throws -> [PlaylistDTO] {
        lastFetchRequest = request
        return try fetchResult.get()
    }

    func fetchPlaylist(_ request: FetchPlaylistRequest) async throws -> PlaylistDTO {
        lastFetchOneRequest = request
        return try fetchOneResult.get()
    }

    func createPlaylist(_ request: CreatePlaylistRequest) async throws -> PlaylistDTO {
        lastCreateRequest = request
        return try createResult.get()
    }

    func updatePlaylist(_ request: UpdatePlaylistRequest) async throws -> PlaylistDTO {
        lastUpdateRequest = request
        return try updateResult.get()
    }
}
