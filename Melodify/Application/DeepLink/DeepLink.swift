import Foundation

enum DeepLink: Equatable {
    case track(id: Int)
    case playlist(id: Int)
    case search(query: String)
}

extension Notification.Name {
    static let handleDeepLink = Notification.Name("melodify.handleDeepLink")
}
