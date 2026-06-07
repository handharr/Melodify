import UIKit

public enum MDSColor {
    // Brand
    public static let primary: UIColor = UIColor(red: 0.22, green: 0.44, blue: 0.85, alpha: 1)
    public static let primaryVariant: UIColor = UIColor(red: 0.15, green: 0.68, blue: 0.51, alpha: 1)
    public static let onPrimary: UIColor = .white

    // Surface
    public static let surface: UIColor = .systemBackground
    public static let surfaceElevated: UIColor = .secondarySystemBackground

    // Semantic
    public static let error: UIColor = .systemRed
    public static let warning: UIColor = .systemOrange
    public static let success: UIColor = .systemGreen

    // Text
    public static let textPrimary: UIColor = .label
    public static let textSecondary: UIColor = .secondaryLabel
    public static let textDisabled: UIColor = .tertiaryLabel
}
