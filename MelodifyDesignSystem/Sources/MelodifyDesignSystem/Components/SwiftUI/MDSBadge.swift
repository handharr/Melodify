import SwiftUI
import UIKit

public struct MDSBadgeModifier: ViewModifier {
    public let count: Int

    public init(count: Int) {
        self.count = count
    }

    public func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            if count > 0 {
                Text(count > 99 ? "99+" : "\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(MDSColor.onPrimary))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(MDSColor.primary))
                    .clipShape(Capsule())
                    .offset(x: 8, y: -8)
            }
        }
    }
}

public extension View {
    func mdsBadge(count: Int) -> some View {
        modifier(MDSBadgeModifier(count: count))
    }
}
