import UIKit
import MelodifyDesignSystem

final class ImageMessageCell: UICollectionViewCell {
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        iv.backgroundColor = MDSColor.surfaceElevated
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let metaLabel: UILabel = {
        let l = UILabel()
        l.font = Typography.caption
        l.textColor = MDSColor.textSecondary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private var aspectConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        contentView.addSubview(metaLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            imageView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.6),

            metaLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 4),
            metaLabel.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            metaLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with model: ChatUIModel) {
        guard case .image(let url, let ratio) = model.content else { return }

        aspectConstraint?.isActive = false
        let aspect = imageView.widthAnchor.constraint(
            equalTo: imageView.heightAnchor,
            multiplier: ratio
        )
        aspect.isActive = true
        aspectConstraint = aspect

        metaLabel.text = model.timestamp

        // Load image — replace with SDWebImage or equivalent in production.
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            await MainActor.run { self.imageView.image = UIImage(data: data) }
        }
    }
}
