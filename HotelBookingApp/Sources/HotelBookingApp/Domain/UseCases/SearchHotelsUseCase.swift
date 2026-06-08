import Foundation

protocol SearchHotelsUseCaseProtocol: Sendable {
    func execute(request: SearchHotelsRequest) async throws -> [HotelListing]
}

final class SearchHotelsUseCase: SearchHotelsUseCaseProtocol, @unchecked Sendable {
    private let repository: HotelRepositoryProtocol

    init(repository: HotelRepositoryProtocol) {
        self.repository = repository
    }

    func execute(request: SearchHotelsRequest) async throws -> [HotelListing] {
        guard !request.query.destination.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return try await repository.searchHotels(request: request)
    }
}
