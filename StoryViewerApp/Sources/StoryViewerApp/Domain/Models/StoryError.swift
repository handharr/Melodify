import Foundation

enum StoryError: Error, Sendable {
    case imageDecodingFailed
    case noStoriesAvailable
}
