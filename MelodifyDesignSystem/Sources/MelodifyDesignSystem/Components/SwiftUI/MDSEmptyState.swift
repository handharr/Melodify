import SwiftUI
import UIKit

/// Native SwiftUI empty state: icon + title + subtitle + optional action button.
/// Same token vocabulary as MDSEmptyStateView — no UIViewRepresentable wrapper
/// needed because this component is fully declarative with no stateful animations.
public struct MDSEmptyState: View {
    public let systemImageName: String
    public let title: String
    public let subtitle: String
    public let actionTitle: String?
    public let action: (() -> Void)?

    public init(
        systemImageName: String,
        title: String,
        subtitle: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImageName = systemImageName
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: systemImageName)
                .font(.system(size: 48))
                .foregroundColor(Color(MDSColor.textSecondary))

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(MDSColor.textPrimary))

            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(Color(MDSColor.textSecondary))
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .mdsButtonStyle(.filled)
                    .padding(.top, Spacing.sm)
            }
        }
        .padding(Spacing.xl)
    }
}
