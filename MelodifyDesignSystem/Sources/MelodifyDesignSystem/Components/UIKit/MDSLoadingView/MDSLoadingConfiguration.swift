import Foundation

public enum MDSLoadingVariant {
    case inline      // transparent background, just spinner + optional label
    case fullscreen  // surface-tinted overlay covering the parent
}

public struct MDSLoadingConfiguration {
    public let variant: MDSLoadingVariant
    public let message: String?

    public init(variant: MDSLoadingVariant = .inline, message: String? = nil) {
        self.variant = variant
        self.message = message
    }
}
