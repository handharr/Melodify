import UIKit

public final class MDSPrimaryButton: UIButton {
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        layer.cornerRadius = Radius.md
        titleLabel?.font = Typography.title
        setTitleColor(MDSColor.onPrimary, for: .normal)
        setTitleColor(MDSColor.onPrimary.withAlphaComponent(0.6), for: .disabled)

        activityIndicator.color = MDSColor.onPrimary
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    public func configure(with config: MDSPrimaryButtonConfiguration) {
        setTitle(config.isLoading ? nil : config.title, for: .normal)
        isEnabled       = config.isEnabled
        backgroundColor = config.isEnabled ? MDSColor.primary : .systemGray4
        config.isLoading ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
    }
}
