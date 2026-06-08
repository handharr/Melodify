import UIKit
import MelodifyDesignSystem

final class BasketItemCell: UITableViewCell {
    static let reuseID = "BasketItemCell"

    private let nameLabel = UILabel()
    private let countLabel = UILabel()
    private let priceLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: BasketUIModel.BasketItemUIModel) {
        nameLabel.text = item.name
        countLabel.text = item.count
        priceLabel.text = item.price
    }

    private func setupLayout() {
        nameLabel.font = Typography.body
        countLabel.font = Typography.caption
        countLabel.textColor = MDSColor.textSecondary
        priceLabel.font = Typography.body
        priceLabel.textAlignment = .right

        let leftStack = UIStackView(arrangedSubviews: [nameLabel, countLabel])
        leftStack.axis = .vertical
        leftStack.spacing = 4

        let row = UIStackView(arrangedSubviews: [leftStack, priceLabel])
        row.axis = .horizontal
        row.distribution = .equalSpacing
        row.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
}
