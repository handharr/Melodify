import Foundation

// Supported URL schemes:
//   melodify://track/123
//   melodify://playlist/456
//   melodify://search?q=coldplay
enum DeepLinkParser {
    static func parse(_ url: URL) -> DeepLink? {
        guard url.scheme == "melodify" else { return nil }
        switch url.host {
        case "track":
            guard let id = Int(url.lastPathComponent) else { return nil }
            return .track(id: id)
        case "playlist":
            guard let id = Int(url.lastPathComponent) else { return nil }
            return .playlist(id: id)
        case "search":
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            guard let query = items?.first(where: { $0.name == "q" })?.value,
                  !query.isEmpty else { return nil }
            return .search(query: query)
        default:
            return nil
        }
    }
}
