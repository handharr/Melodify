import UIKit

public final class MDSPrimaryButton: UIButton {
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        layer.cornerRadius = 12
        titleLabel?.font = .titleMedium
        setTitleColor(.white, for: .normal)
        setTitleColor(.white.withAlphaComponent(0.6), for: .disabled)

        activityIndicator.color = .white
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    public func configure(with config: MDSPrimaryButtonConfiguration) {
        setTitle(config.isLoading ? nil : config.title, for: .normal)
        isEnabled        = config.isEnabled
        backgroundColor  = config.isEnabled ? .brandPrimary : .systemGray4
        config.isLoading ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
    }
}
