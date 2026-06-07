import Foundation
import Combine

@MainActor
final class TrackDetailViewModel {
    @Published private(set) var detail: TrackDetailUIModel?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading: Bool = false

    private let trackId: Int
    private let getTrackDetailUseCase: GetTrackDetailUseCaseProtocol

    init(trackId: Int, getTrackDetailUseCase: GetTrackDetailUseCaseProtocol) {
        self.trackId = trackId
        self.getTrackDetailUseCase = getTrackDetailUseCase
    }

    func load() {
        Task {
            defer { isLoading = false }
            do {
                isLoading = true
                let track = try await getTrackDetailUseCase.execute(
                    request: GetTrackDetailRequest(path: GetTrackDetailPath(id: trackId), policy: .fresh)
                )
                detail = TrackDetailUIModelMapper.toUIModel(track)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
