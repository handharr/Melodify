import UIKit
import MelodifyDesignSystem

final class DishCell: UICollectionViewCell {
    static let reuseID = "DishCell"

    private let dishImageView = UIImageView()
    private let nameLabel = UILabel()
    private let priceLabel = UILabel()

    var onAdd: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with model: DishUIModel) {
        nameLabel.text = model.name
        priceLabel.text = model.price
        dishImageView.setImage(url: model.imageURL)
    }

    private func setupLayout() {
        contentView.backgroundColor = MDSColor.surfaceElevated
        contentView.layer.cornerRadius = Radius.md
        contentView.clipsToBounds = true

        dishImageView.contentMode = .scaleAspectFill
        dishImageView.clipsToBounds = true
        dishImageView.backgroundColor = MDSColor.surface
        dishImageView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = Typography.body
        nameLabel.numberOfLines = 2

        priceLabel.font = Typography.caption
        priceLabel.textColor = MDSColor.textSecondary

        let addButton = UIButton(type: .system)
        addButton.setTitle("+ Add", for: .normal)
        addButton.titleLabel?.font = Typography.caption
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, priceLabel, addButton])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(dishImageView)
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            dishImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            dishImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            dishImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            dishImageView.heightAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.6),
            textStack.topAnchor.constraint(equalTo: dishImageView.bottomAnchor, constant: 8),
            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    @objc private func addTapped() { onAdd?() }
}
