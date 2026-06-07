import UIKit

public struct ShadowToken: @unchecked Sendable {
    public let color: UIColor
    public let opacity: Float
    public let offset: CGSize
    public let radius: CGFloat
}

public enum Elevation {
    public static let low = ShadowToken(
        color: .black, opacity: 0.08,
        offset: CGSize(width: 0, height: 1), radius: 2
    )
    public static let mid = ShadowToken(
        color: .black, opacity: 0.12,
        offset: CGSize(width: 0, height: 4), radius: 8
    )
    public static let high = ShadowToken(
        color: .black, opacity: 0.16,
        offset: CGSize(width: 0, height: 8), radius: 16
    )
}

public extension UIView {
    func applyShadow(_ token: ShadowToken) {
        layer.shadowColor = token.color.cgColor
        layer.shadowOpacity = token.opacity
        layer.shadowOffset = token.offset
        layer.shadowRadius = token.radius
        layer.masksToBounds = false
    }
}
