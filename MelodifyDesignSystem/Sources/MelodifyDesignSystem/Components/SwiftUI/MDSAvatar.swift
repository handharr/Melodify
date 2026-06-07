import SwiftUI
import UIKit

/// Native SwiftUI avatar with async image loading and initials fallback.
/// Same visual tokens as MDSAvatarView — no UIViewRepresentable wrapper needed
/// because this component has no stateful animations that require UIKit lifecycle.
public struct MDSAvatar: View {
    public let name: String
    public let imageURL: URL?
    public let size: MDSAvatarSize

    public init(name: String, imageURL: URL? = nil, size: MDSAvatarSize = .medium) {
        self.name = name
        self.imageURL = imageURL
        self.size = size
    }

    private var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map { String($0) } }
            .joined()
            .uppercased()
    }

    public var body: some View {
        ZStack {
            Circle().fill(Color(MDSColor.primary))
            if let url = imageURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: size.dimension, height: size.dimension)
        .clipShape(Circle())
    }

    private var initialsView: some View {
        Text(initials)
            .font(.system(size: size.fontSize, weight: .semibold))
            .foregroundColor(Color(MDSColor.onPrimary))
    }
}
