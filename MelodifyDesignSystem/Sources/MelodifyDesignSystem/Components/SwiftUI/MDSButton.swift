import SwiftUI
import UIKit

public enum MDSButtonVariant {
    case filled
    case outlined
}

public struct MDSButtonStyle: ButtonStyle {
    public let variant: MDSButtonVariant

    public init(variant: MDSButtonVariant = .filled) {
        self.variant = variant
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(foreground)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(background)
            .cornerRadius(Radius.md)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }

    @ViewBuilder private var background: some View {
        switch variant {
        case .filled:
            Color(MDSColor.primary)
        case .outlined:
            Color.clear.overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color(MDSColor.primary), lineWidth: 1.5)
            )
        }
    }

    private var foreground: Color {
        switch variant {
        case .filled:   return Color(MDSColor.onPrimary)
        case .outlined: return Color(MDSColor.primary)
        }
    }
}

public extension View {
    func mdsButtonStyle(_ variant: MDSButtonVariant = .filled) -> some View {
        buttonStyle(MDSButtonStyle(variant: variant))
    }
}
