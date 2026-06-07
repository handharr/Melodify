import UIKit

public final class MDSBadgeView: UIView {
    private let countLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .bold)
        l.textColor = MDSColor.onPrimary
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = MDSColor.primary
        addSubview(countLabel)
        NSLayoutConstraint.activate([
            countLabel.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            countLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            countLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 16),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 16)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    public override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    public func configure(with config: MDSBadgeConfiguration) {
        isHidden = config.count == 0
        countLabel.text = config.count > 99 ? "99+" : "\(config.count)"
    }
}
