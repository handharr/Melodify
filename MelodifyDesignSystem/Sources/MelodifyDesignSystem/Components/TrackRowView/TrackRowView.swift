import UIKit

public final class MDSTrackRowView: UIView {
    private let artworkView: UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.layer.cornerRadius = 8
        v.backgroundColor = .backgroundElevated
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .titleMedium
        l.textColor = .textPrimary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = .bodyRegular
        l.textColor = .textSecondary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let durationLabel: UILabel = {
        let l = UILabel()
        l.font = .captionSmall
        l.textColor = .textSecondary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private var imageTask: Task<Void, Never>?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    public func configure(with config: MDSTrackRowConfiguration) {
        titleLabel.text    = config.title
        subtitleLabel.text = config.subtitle
        durationLabel.text = config.duration
        artworkView.image  = nil

        imageTask?.cancel()
        guard let url = config.artworkURL else { return }
        imageTask = Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data),
                  !Task.isCancelled else { return }
            await MainActor.run { self?.artworkView.image = image }
        }
    }

    private func setupLayout() {
        [artworkView, titleLabel, subtitleLabel, durationLabel].forEach { addSubview($0) }

        NSLayoutConstraint.activate([
            artworkView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Spacing.md),
            artworkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            artworkView.widthAnchor.constraint(equalToConstant: 48),
            artworkView.heightAnchor.constraint(equalToConstant: 48),
            artworkView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: Spacing.sm),
            artworkView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -Spacing.sm),

            titleLabel.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: Spacing.sm),
            titleLabel.topAnchor.constraint(equalTo: artworkView.topAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -Spacing.sm),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Spacing.xs),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            durationLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Spacing.md),
            durationLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
