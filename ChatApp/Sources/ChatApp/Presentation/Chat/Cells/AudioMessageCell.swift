import UIKit

final class AudioMessageCell: UICollectionViewCell {
    private let iconView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "waveform"))
        iv.tintColor = .systemBlue
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let durationLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let metaLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11)
        l.textColor = .tertiaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let bubbleView: UIView = {
        let v = UIView()
        v.backgroundColor = .secondarySystemBackground
        v.layer.cornerRadius = 16
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        bubbleView.addSubview(iconView)
        bubbleView.addSubview(durationLabel)
        contentView.addSubview(bubbleView)
        contentView.addSubview(metaLabel)

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),

            iconView.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            iconView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            iconView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10),

            durationLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            durationLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            durationLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),

            metaLabel.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 4),
            metaLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
            metaLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with model: ChatUIModel) {
        guard case .audio(let duration, _) = model.content else { return }
        durationLabel.text = duration
        metaLabel.text = model.timestamp
    }
}
