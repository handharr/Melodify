import Foundation

public struct MDSAudioPlayerConfiguration {
    public let duration: String
    public let isPlaying: Bool
    public let variant: MDSBubbleVariant  // shares outgoing/incoming styling with MDSMessageBubble

    public init(duration: String, isPlaying: Bool = false, variant: MDSBubbleVariant = .incoming) {
        self.duration = duration
        self.isPlaying = isPlaying
        self.variant = variant
    }
}
