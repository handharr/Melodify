import UIKit
import MelodifyDesignSystem

final class TextMessageCell: UICollectionViewCell {
    private let bubble: MDSMessageBubble = {
        let v = MDSMessageBubble()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(bubble)

        let leading  = bubble.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.md)
        let trailing = bubble.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Spacing.md)
        leadingConstraint  = leading
        trailingConstraint = trailing

        NSLayoutConstraint.activate([
            bubble.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Spacing.xs),
            bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Spacing.xs),
            bubble.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with model: ChatUIModel) {
        guard case .text(let text) = model.content else { return }
        let variant: MDSBubbleVariant = model.isOutgoing ? .outgoing : .incoming
        bubble.configure(with: MDSMessageBubbleConfiguration(
            text: text,
            variant: variant,
            meta: "\(model.timestamp) · \(model.status)"
        ))

        if model.isOutgoing {
            leadingConstraint?.isActive  = false
            trailingConstraint?.isActive = true
        } else {
            trailingConstraint?.isActive = false
            leadingConstraint?.isActive  = true
        }
    }
}
