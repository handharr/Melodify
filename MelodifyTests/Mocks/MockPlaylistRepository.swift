import Foundation
@testable import Melodify

final class MockPlaylistRepository: PlaylistRepositoryProtocol {
    var fetchResult: Result<[Playlist], Error> = .success([])
    var fetchOneResult: Result<Playlist, Error> = .success(.stub())
    var createResult: Result<Playlist, Error> = .success(.stub())
    var updateResult: Result<Playlist, Error> = .success(.stub())

    private(set) var lastFetchPolicy: FetchPolicy?
    private(set) var lastFetchOneId: Int?
    private(set) var lastCreateParam: CreatePlaylistParam?
    private(set) var lastUpdateParam: UpdatePlaylistParam?

    func fetchPlaylists(policy: FetchPolicy) async throws -> [Playlist] {
        lastFetchPolicy = policy
        return try fetchResult.get()
    }

    func fetchPlaylist(id: Int, policy: FetchPolicy) async throws -> Playlist {
        lastFetchOneId = id
        return try fetchOneResult.get()
    }

    func createPlaylist(param: CreatePlaylistParam) async throws -> Playlist {
        lastCreateParam = param
        return try createResult.get()
    }

    func updatePlaylist(param: UpdatePlaylistParam) async throws -> Playlist {
        lastUpdateParam = param
        return try updateResult.get()
    }
}
