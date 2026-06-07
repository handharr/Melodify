import SwiftUI
import UIKit

/// Translucent full-screen loading overlay for SwiftUI screens.
/// Visually identical to MDSLoadingView (fullscreen variant) — two implementations
/// for two contexts. Embed via .overlay { MDSLoadingOverlay() } on any View.
public struct MDSLoadingOverlay: View {
    public let message: String?

    public init(message: String? = nil) {
        self.message = message
    }

    public var body: some View {
        ZStack {
            Color(MDSColor.surface)
                .opacity(0.8)
                .ignoresSafeArea()
            VStack(spacing: Spacing.sm) {
                ProgressView()
                if let message {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(Color(MDSColor.textSecondary))
                }
            }
        }
    }
}
