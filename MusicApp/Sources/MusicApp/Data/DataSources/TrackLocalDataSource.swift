import Foundation

final class TrackLocalDataSource: TrackLocalDataSourceProtocol {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func searchTracks(request: TrackSearchAPIRequest) -> [TrackDTO]? {
        guard let data = defaults.data(forKey: searchKey(for: request)) else { return nil }
        return try? JSONDecoder().decode([TrackDTO].self, from: data)
    }

    func saveSearchTracks(_ tracks: [TrackDTO], for request: TrackSearchAPIRequest) {
        defaults.set(try? JSONEncoder().encode(tracks), forKey: searchKey(for: request))
    }

    func getTrackDetail(request: TrackDetailAPIRequest) -> TrackDTO? {
        guard let data = defaults.data(forKey: detailKey(for: request)) else { return nil }
        return try? JSONDecoder().decode(TrackDTO.self, from: data)
    }

    func saveTrackDetail(_ track: TrackDTO, for request: TrackDetailAPIRequest) {
        defaults.set(try? JSONEncoder().encode(track), forKey: detailKey(for: request))
    }

    private func searchKey(for request: TrackSearchAPIRequest) -> String {
        "music.search.\(request.query).\(request.offset).\(request.limit)"
    }

    private func detailKey(for request: TrackDetailAPIRequest) -> String {
        "music.detail.\(request.id)"
    }
}
