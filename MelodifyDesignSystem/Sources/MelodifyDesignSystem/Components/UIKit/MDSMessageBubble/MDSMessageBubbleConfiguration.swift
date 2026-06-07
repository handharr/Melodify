import Foundation

public enum MDSBubbleVariant {
    case outgoing  // blue background, right-aligned
    case incoming  // surface background, left-aligned
}

public struct MDSMessageBubbleConfiguration {
    public let text: String
    public let variant: MDSBubbleVariant
    public let meta: String  // combined timestamp + status string

    public init(text: String, variant: MDSBubbleVariant, meta: String) {
        self.text = text
        self.variant = variant
        self.meta = meta
    }
}
