import UIKit

final class TextMessageCell: UICollectionViewCell {
    private let bubbleView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 16
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let textLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16)
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let metaLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11)
        l.textColor = .tertiaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        bubbleView.addSubview(textLabel)
        bubbleView.addSubview(metaLabel)
        contentView.addSubview(bubbleView)

        let leading = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        let trailing = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        leadingConstraint = leading
        trailingConstraint = trailing

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75),

            textLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            textLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            textLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),

            metaLabel.topAnchor.constraint(equalTo: textLabel.bottomAnchor, constant: 4),
            metaLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            metaLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with model: ChatUIModel) {
        guard case .text(let text) = model.content else { return }
        textLabel.text = text
        metaLabel.text = "\(model.timestamp) · \(model.status)"

        if model.isOutgoing {
            bubbleView.backgroundColor = .systemBlue
            textLabel.textColor = .white
            leadingConstraint?.isActive = false
            trailingConstraint?.isActive = true
        } else {
            bubbleView.backgroundColor = .secondarySystemBackground
            textLabel.textColor = .label
            trailingConstraint?.isActive = false
            leadingConstraint?.isActive = true
        }
    }
}
