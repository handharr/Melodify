import UIKit
import MelodifyDesignSystem

final class ConversationCell: UITableViewCell {
    static let reuseIdentifier = "ConversationCell"

    private let avatarView: MDSAvatarView = {
        let v = MDSAvatarView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = Typography.title
        l.textColor = MDSColor.textPrimary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let lastMessageLabel: UILabel = {
        let l = UILabel()
        l.font = Typography.body
        l.textColor = MDSColor.textSecondary
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let timestampLabel: UILabel = {
        let l = UILabel()
        l.font = Typography.caption
        l.textColor = MDSColor.textDisabled
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let badgeView: MDSBadgeView = {
        let v = MDSBadgeView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with model: ConversationUIModel) {
        avatarView.configure(with: MDSAvatarConfiguration(name: model.title, size: .medium))
        titleLabel.text = model.title
        lastMessageLabel.text = model.lastMessage
        timestampLabel.text = model.timestamp
        badgeView.configure(with: MDSBadgeConfiguration(count: model.unreadCount))
    }

    private func setupViews() {
        [avatarView, titleLabel, lastMessageLabel, timestampLabel, badgeView]
            .forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.md),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: Spacing.sm),
            avatarView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -Spacing.sm),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Spacing.sm + 4),
            titleLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: Spacing.sm),
            titleLabel.trailingAnchor.constraint(equalTo: timestampLabel.leadingAnchor, constant: -Spacing.sm),

            timestampLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            timestampLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Spacing.md),

            lastMessageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Spacing.xs),
            lastMessageLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            lastMessageLabel.trailingAnchor.constraint(equalTo: badgeView.leadingAnchor, constant: -Spacing.sm),
            lastMessageLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -(Spacing.sm + 4)),

            badgeView.centerYAnchor.constraint(equalTo: lastMessageLabel.centerYAnchor),
            badgeView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Spacing.md)
        ])
    }
}
