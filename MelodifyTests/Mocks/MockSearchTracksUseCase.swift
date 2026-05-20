import Foundation
@testable import Melodify

final class MockSearchTracksUseCase: SearchTracksUseCaseProtocol {
    var stubbedResult: Result<[Track], Error> = .success([])
    var executedParams: [SearchTracksParam] = []

    func execute(policy: FetchPolicy, param: SearchTracksParam) async throws -> [Track] {
        executedParams.append(param)
        return try stubbedResult.get()
    }
}
