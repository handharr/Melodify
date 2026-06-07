import Foundation

protocol TrackLocalDataSourceProtocol {
    func searchTracks(request: TrackSearchRequest) -> [TrackDTO]?
    func saveSearchTracks(_ tracks: [TrackDTO], for request: TrackSearchRequest)
    func getTrackDetail(request: TrackDetailRequest) -> TrackDTO?
    func saveTrackDetail(_ track: TrackDTO, for request: TrackDetailRequest)
}
