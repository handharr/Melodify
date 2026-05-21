import UIKit

public final class MDSEmptyStateView: UIView {
    private let imageView: UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFit
        v.tintColor = .textSecondary
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .titleMedium
        l.textColor = .textPrimary
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = .bodyRegular
        l.textColor = .textSecondary
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let actionButton: MDSPrimaryButton = {
        let b = MDSPrimaryButton()
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    public var onAction: (() -> Void)?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }

    public func configure(with config: MDSEmptyStateConfiguration) {
        imageView.image    = UIImage(systemName: config.systemImageName)
        titleLabel.text    = config.title
        subtitleLabel.text = config.subtitle

        if let buttonTitle = config.buttonTitle {
            actionButton.configure(with: MDSPrimaryButtonConfiguration(title: buttonTitle))
            actionButton.isHidden = false
        } else {
            actionButton.isHidden = true
        }
    }

    @objc private func actionTapped() { onAction?() }

    private func setupLayout() {
        [imageView, titleLabel, subtitleLabel, actionButton].forEach { addSubview($0) }

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: Spacing.lg),
            imageView.widthAnchor.constraint(equalToConstant: 64),
            imageView.heightAnchor.constraint(equalToConstant: 64),

            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: Spacing.md),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Spacing.lg),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Spacing.lg),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Spacing.sm),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            actionButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: Spacing.lg),
            actionButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: 200),
            actionButton.heightAnchor.constraint(equalToConstant: 48),
            actionButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Spacing.lg)
        ])
    }
}
