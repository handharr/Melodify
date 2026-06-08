import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {

    // MARK: - Input state

    @Published var destination: String = ""
    @Published var checkIn: String = ""
    @Published var checkOut: String = ""
    @Published var guestCount: Int = 1

    // MARK: - Output state

    @Published private(set) var autocompleteResults: [HotelCardUIModel] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    // MARK: - Coordinator callback

    var onSearch: (([HotelListing]) -> Void)?

    // MARK: - Private

    private let searchHotelsUseCase: SearchHotelsUseCaseProtocol
    private let hotelLocalDataSource: HotelLocalDataSourceProtocol
    private var debounceTask: Task<Void, Never>?

    // MARK: - Init

    init(
        searchHotelsUseCase: SearchHotelsUseCaseProtocol,
        hotelLocalDataSource: HotelLocalDataSourceProtocol
    ) {
        self.searchHotelsUseCase = searchHotelsUseCase
        self.hotelLocalDataSource = hotelLocalDataSource
    }

    // MARK: - Autocomplete

    func didChangeDestination(query: String) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self.runAutocomplete(query: query)
        }
    }

    private func runAutocomplete(query: String) async {
        guard !query.isEmpty else {
            autocompleteResults = []
            return
        }

        // Phase 1: local prefix search
        let local = hotelLocalDataSource.searchPrefix(query: query)
        if !local.isEmpty {
            autocompleteResults = local.compactMap { dto -> HotelCardUIModel? in
                guard let thumbnailURL = URL(string: dto.mediaUrl) else { return nil }
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.currencySymbol = "$"
                formatter.maximumFractionDigits = 0
                let priceText = formatter.string(from: dto.price as NSDecimalNumber) ?? "$\(dto.price)"
                return HotelCardUIModel(
                    id: dto.hotelId,
                    name: dto.hotelId,
                    location: dto.location,
                    priceText: priceText,
                    rating: dto.rating,
                    thumbnailURL: thumbnailURL
                )
            }
            return
        }

        // Phase 2: remote fetch when local is empty
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let searchQuery = SearchHotelsQuery(
                destination: query,
                checkIn: checkIn,
                checkOut: checkOut,
                guestCount: guestCount
            )
            let request = SearchHotelsRequest(query: searchQuery, policy: .fresh)
            let listings = try await searchHotelsUseCase.execute(request: request)
            autocompleteResults = listings.map { listing in
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.currencySymbol = "$"
                formatter.maximumFractionDigits = 0
                let priceText = formatter.string(from: listing.price as NSDecimalNumber) ?? "$\(listing.price)"
                return HotelCardUIModel(
                    id: listing.hotelId,
                    name: listing.hotelId,
                    location: listing.location,
                    priceText: priceText,
                    rating: listing.rating,
                    thumbnailURL: listing.thumbnailUrl
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Full search

    func searchQuery() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            guard let self else { return }
            await self.performSearch()
        }
    }

    private func performSearch() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let searchQuery = SearchHotelsQuery(
                destination: destination,
                checkIn: checkIn,
                checkOut: checkOut,
                guestCount: guestCount
            )
            let request = SearchHotelsRequest(query: searchQuery, policy: .fresh)
            let listings = try await searchHotelsUseCase.execute(request: request)
            onSearch?(listings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
