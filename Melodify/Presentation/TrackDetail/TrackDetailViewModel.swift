import Foundation
import Combine

@MainActor
final class TrackDetailViewModel {

    @Published private(set) var track: Track?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading: Bool = false
    
    private let getTrackDetailUseCase: GetTrackDetailUseCaseProtocol

    init(track: Track?, getTrackDetailUseCase: GetTrackDetailUseCaseProtocol) {
        self.track = track
        self.getTrackDetailUseCase = getTrackDetailUseCase
    }

    var duration: String {
        let seconds = (track?.durationMs ?? 0) / 1000
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
    
    func load() {
        guard let id = self.track?.id else { return }
        
        Task {
            defer {
                isLoading = false
            }
            do {
                isLoading = true
                let track = try await self.getTrackDetailUseCase.execute(fetchPolicy: .fresh, param: GetTrackDetailParam(path: GetTrackDetailPath(id: id)))
                self.track = track
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
