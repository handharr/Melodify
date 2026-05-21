import Foundation
@testable import Melodify

final class MockPlaylistDetailUseCase: PlaylistDetailUseCaseProtocol {
    var stubbedResult: Result<PlaylistDetail, Error> = .success(PlaylistDetail(playlist: .stub(), tracks: []))
    private(set) var executedParam: PlaylistDetailParam?

    func execute(policy: FetchPolicy, param: PlaylistDetailParam) async throws -> PlaylistDetail {
        executedParam = param
        return try stubbedResult.get()
    }
}
