import UIKit

public final class MDSLoadingView: UIView {
    private let spinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.translatesAutoresizingMaskIntoConstraints = false
        s.startAnimating()
        return s
    }()

    private let messageLabel: UILabel = {
        let l = UILabel()
        l.font = Typography.caption
        l.textColor = MDSColor.textSecondary
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView(arrangedSubviews: [spinner, messageLabel])
        stack.axis = .vertical
        stack.spacing = Spacing.sm
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: Spacing.md),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Spacing.md)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    public func configure(with config: MDSLoadingConfiguration) {
        messageLabel.text = config.message
        messageLabel.isHidden = config.message == nil
        backgroundColor = config.variant == .fullscreen
            ? MDSColor.surface.withAlphaComponent(0.8)
            : .clear
    }
}
