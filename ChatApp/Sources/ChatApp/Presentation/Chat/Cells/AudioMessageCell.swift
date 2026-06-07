import UIKit
import MelodifyDesignSystem

final class AudioMessageCell: UICollectionViewCell {
    private let playerView: MDSAudioPlayerView = {
        let v = MDSAudioPlayerView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let metaLabel: UILabel = {
        let l = UILabel()
        l.font = Typography.caption
        l.textColor = MDSColor.textDisabled
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(playerView)
        contentView.addSubview(metaLabel)

        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Spacing.xs),
            playerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.md),

            metaLabel.topAnchor.constraint(equalTo: playerView.bottomAnchor, constant: Spacing.xs),
            metaLabel.leadingAnchor.constraint(equalTo: playerView.leadingAnchor),
            metaLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Spacing.xs)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with model: ChatUIModel) {
        guard case .audio(let duration, _) = model.content else { return }
        playerView.configure(with: MDSAudioPlayerConfiguration(
            duration: duration,
            isPlaying: false,
            variant: model.isOutgoing ? .outgoing : .incoming
        ))
        metaLabel.text = model.timestamp
    }
}
