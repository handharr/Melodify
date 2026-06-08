import Foundation

protocol FetchHotelDetailUseCaseProtocol: Sendable {
    func execute(request: FetchHotelDetailRequest) async throws -> Hotel
}

final class FetchHotelDetailUseCase: FetchHotelDetailUseCaseProtocol, @unchecked Sendable {
    private let repository: HotelRepositoryProtocol

    init(repository: HotelRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: FetchHotelDetailRequest) async throws -> Hotel {
        try await repository.fetchHotelDetail(request: request)
    }
}
