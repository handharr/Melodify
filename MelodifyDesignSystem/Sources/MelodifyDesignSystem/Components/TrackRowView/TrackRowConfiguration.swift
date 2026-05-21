import Foundation

public struct MDSTrackRowConfiguration {
    public let title: String
    public let subtitle: String
    public let duration: String
    public var artworkURL: URL?

    public init(title: String, subtitle: String, duration: String, artworkURL: URL? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.duration = duration
        self.artworkURL = artworkURL
    }
}
