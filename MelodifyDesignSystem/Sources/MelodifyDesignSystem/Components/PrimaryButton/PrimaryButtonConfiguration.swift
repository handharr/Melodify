import Foundation

public struct MDSPrimaryButtonConfiguration {
    public let title: String
    public var isEnabled: Bool
    public var isLoading: Bool

    public init(title: String, isEnabled: Bool = true, isLoading: Bool = false) {
        self.title = title
        self.isEnabled = isEnabled
        self.isLoading = isLoading
    }
}
