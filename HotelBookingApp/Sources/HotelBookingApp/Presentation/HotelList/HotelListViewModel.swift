import Foundation
import Combine

@MainActor
final class HotelListViewModel: ObservableObject {

    // MARK: - Output state

    @Published private(set) var hotels: [HotelListUIModel] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    // MARK: - Coordinator callback

    var onSelectHotel: ((HotelListing) -> Void)?

    // MARK: - Private

    private let searchHotelsUseCase: SearchHotelsUseCaseProtocol
    private let baseQuery: SearchHotelsQuery
    private var currentOffset: Int = 0
    private let limit: Int = 25
    private var allListings: [HotelListing] = []

    // MARK: - Init

    init(
        searchHotelsUseCase: SearchHotelsUseCaseProtocol,
        query: SearchHotelsQuery
    ) {
        self.searchHotelsUseCase = searchHotelsUseCase
        self.baseQuery = query
    }

    // MARK: - Load

    func loadHotels() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        currentOffset = 0
        allListings = []

        let pageQuery = SearchHotelsQuery(
            destination: baseQuery.destination,
            checkIn: baseQuery.checkIn,
            checkOut: baseQuery.checkOut,
            guestCount: baseQuery.guestCount,
            offset: currentOffset,
            limit: limit
        )

        // Phase 1: strict (cache-only) — publish immediately if available
        if let cached = try? await searchHotelsUseCase.execute(
            request: SearchHotelsRequest(query: pageQuery, policy: .strict)
        ) {
            allListings = cached
            hotels = cached.map { HotelListUIModelMapper.toUIModel($0) }
        }

        // Phase 2: fresh (network) — overwrite with latest
        do {
            let fresh = try await searchHotelsUseCase.execute(
                request: SearchHotelsRequest(query: pageQuery, policy: .fresh)
            )
            allListings = fresh
            hotels = fresh.map { HotelListUIModelMapper.toUIModel($0) }
        } catch {
            if hotels.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Pagination

    func loadNextPage() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        currentOffset += limit

        let pageQuery = SearchHotelsQuery(
            destination: baseQuery.destination,
            checkIn: baseQuery.checkIn,
            checkOut: baseQuery.checkOut,
            guestCount: baseQuery.guestCount,
            offset: currentOffset,
            limit: limit
        )

        do {
            let next = try await searchHotelsUseCase.execute(
                request: SearchHotelsRequest(query: pageQuery, policy: .fresh)
            )
            allListings.append(contentsOf: next)
            hotels = allListings.map { HotelListUIModelMapper.toUIModel($0) }
        } catch {
            currentOffset -= limit
            errorMessage = error.localizedDescription
        }
    }
}
