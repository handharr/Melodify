import UIKit
import MelodifyDesignSystem

final class DeletedMessageCell: UICollectionViewCell {
    private let label: UILabel = {
        let l = UILabel()
        l.text = "This message was deleted"
        l.font = .italicSystemFont(ofSize: Typography.body.pointSize)
        l.textColor = MDSColor.textDisabled
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Spacing.sm),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.md),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Spacing.md),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Spacing.sm)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}
