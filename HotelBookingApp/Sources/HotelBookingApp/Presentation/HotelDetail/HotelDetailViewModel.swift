import Foundation
import Combine

@MainActor
final class HotelDetailViewModel: ObservableObject {

    // MARK: - Output state

    @Published private(set) var detail: HotelDetailUIModel?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    // MARK: - Coordinator callback

    var onReserve: ((Hotel) -> Void)?

    // MARK: - Private

    private let hotelId: String
    private let fetchHotelDetailUseCase: FetchHotelDetailUseCaseProtocol
    private let imageService: ImageServiceProtocol
    private var rawHotel: Hotel?

    // MARK: - Init

    init(
        hotelId: String,
        fetchHotelDetailUseCase: FetchHotelDetailUseCaseProtocol,
        imageService: ImageServiceProtocol
    ) {
        self.hotelId = hotelId
        self.fetchHotelDetailUseCase = fetchHotelDetailUseCase
        self.imageService = imageService
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        let path = FetchHotelDetailPath(hotelId: hotelId)

        // Phase 1: strict (cache-only)
        if let cached = try? await fetchHotelDetailUseCase.execute(
            request: FetchHotelDetailRequest(path: path, policy: .strict)
        ) {
            rawHotel = cached
            detail = HotelDetailUIModelMapper.toUIModel(cached)
        }

        // Phase 2: fresh (network)
        do {
            let fresh = try await fetchHotelDetailUseCase.execute(
                request: FetchHotelDetailRequest(path: path, policy: .fresh)
            )
            rawHotel = fresh
            let uiModel = HotelDetailUIModelMapper.toUIModel(fresh)
            detail = uiModel

            // Load thumbnail images concurrently
            _ = try? await imageService.loadImages(urls: uiModel.thumbnailURLs)
        } catch {
            if detail == nil {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Actions

    func reserve() {
        guard let hotel = rawHotel else { return }
        onReserve?(hotel)
    }
}
