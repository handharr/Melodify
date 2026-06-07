import Foundation

// No optionals for content type — switch exhaustively in the cell factory.
// An optional `text` creates invalid states at the type level; this enum makes
// them compile-time impossible.
enum MessageContent: Sendable, Equatable {
    case text(String)
    case image(URL, aspectRatio: CGFloat)
    case audio(duration: TimeInterval, url: URL)
    case deleted
}

extension MessageContent {
    var type: String {
        switch self {
        case .text:    return "text"
        case .image:   return "image"
        case .audio:   return "audio"
        case .deleted: return "deleted"
        }
    }

    var textValue: String? {
        guard case .text(let t) = self else { return nil }
        return t
    }
}
