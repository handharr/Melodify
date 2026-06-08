import UIKit
import MelodifyDesignSystem

final class RestaurantCell: UITableViewCell {
    static let reuseID = "RestaurantCell"

    private let restaurantImageView = UIImageView()
    private let nameLabel = UILabel()
    private let ratingLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with model: RestaurantUIModel) {
        nameLabel.text = model.name
        ratingLabel.text = model.rating
        restaurantImageView.setImage(url: model.imageURL)
    }

    private func setupLayout() {
        restaurantImageView.contentMode = .scaleAspectFill
        restaurantImageView.clipsToBounds = true
        restaurantImageView.layer.cornerRadius = Radius.sm
        restaurantImageView.backgroundColor = MDSColor.surfaceElevated
        restaurantImageView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = Typography.title
        nameLabel.numberOfLines = 1

        ratingLabel.font = Typography.caption
        ratingLabel.textColor = MDSColor.textSecondary

        let textStack = UIStackView(arrangedSubviews: [nameLabel, ratingLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(restaurantImageView)
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            restaurantImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            restaurantImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            restaurantImageView.widthAnchor.constraint(equalToConstant: 64),
            restaurantImageView.heightAnchor.constraint(equalToConstant: 64),
            restaurantImageView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 12),
            restaurantImageView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),

            textStack.leadingAnchor.constraint(equalTo: restaurantImageView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
}
