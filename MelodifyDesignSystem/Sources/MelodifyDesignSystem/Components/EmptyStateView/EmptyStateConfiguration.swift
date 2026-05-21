import Foundation

public struct MDSEmptyStateConfiguration {
    public let systemImageName: String
    public let title: String
    public let subtitle: String
    public var buttonTitle: String?

    public init(systemImageName: String, title: String, subtitle: String, buttonTitle: String? = nil) {
        self.systemImageName = systemImageName
        self.title = title
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
    }
}
