import Foundation

protocol TrackLocalDataSourceProtocol {
    func searchTracks(request: TrackSearchAPIRequest) -> [TrackDTO]?
    func saveSearchTracks(_ tracks: [TrackDTO], for request: TrackSearchAPIRequest)
    func getTrackDetail(request: TrackDetailAPIRequest) -> TrackDTO?
    func saveTrackDetail(_ track: TrackDTO, for request: TrackDetailAPIRequest)
}
