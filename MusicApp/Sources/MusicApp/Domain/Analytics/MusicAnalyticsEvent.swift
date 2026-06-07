import CoreKit

public enum MusicAnalyticsEvent: AnalyticsEvent {
    case searchPerformed(query: String, resultCount: Int)
    case trackSelected(id: Int, title: String)
    case playlistOpened(id: Int, name: String)
    case screenViewed(name: String)

    public var name: String {
        switch self {
        case .searchPerformed: return "search_performed"
        case .trackSelected: return "track_selected"
        case .playlistOpened: return "playlist_opened"
        case .screenViewed: return "screen_viewed"
        }
    }

    public var params: [String: String] {
        switch self {
        case let .searchPerformed(query, count):
            return ["query": query, "result_count": String(count)]
        case let .trackSelected(id, title):
            return ["track_id": String(id), "title": title]
        case let .playlistOpened(id, name):
            return ["playlist_id": String(id), "name": name]
        case let .screenViewed(name):
            return ["screen": name]
        }
    }
}
