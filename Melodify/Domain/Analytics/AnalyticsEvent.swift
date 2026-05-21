enum AnalyticsEvent {
    case screenViewed(name: String)
    case searchPerformed(query: String, resultCount: Int)
    case trackSelected(id: Int, title: String)
    case playlistOpened(id: Int, name: String)
}
