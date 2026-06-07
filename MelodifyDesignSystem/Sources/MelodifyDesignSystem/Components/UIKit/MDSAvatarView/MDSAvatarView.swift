import UIKit

public final class MDSAvatarView: UIView {
    private let imageView: UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let initialsLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.textColor = MDSColor.onPrimary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private var imageTask: Task<Void, Never>?
    private var sizeConstraints: [NSLayoutConstraint] = []

    public override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(initialsLabel)
        addSubview(imageView)
        NSLayoutConstraint.activate([
            initialsLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            initialsLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    public func configure(with config: MDSAvatarConfiguration) {
        let dim = config.size.dimension

        NSLayoutConstraint.deactivate(sizeConstraints)
        sizeConstraints = [
            widthAnchor.constraint(equalToConstant: dim),
            heightAnchor.constraint(equalToConstant: dim)
        ]
        NSLayoutConstraint.activate(sizeConstraints)

        layer.cornerRadius = dim / 2
        layer.masksToBounds = true
        imageView.layer.cornerRadius = dim / 2
        initialsLabel.font = .systemFont(ofSize: config.size.fontSize, weight: .semibold)

        let initials = config.name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map { String($0) } }
            .joined()
            .uppercased()
        initialsLabel.text = initials
        backgroundColor = MDSColor.primary

        imageView.image = nil
        imageTask?.cancel()
        guard let url = config.imageURL else { return }
        imageTask = Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data),
                  !Task.isCancelled else { return }
            await MainActor.run { self?.imageView.image = image }
        }
    }
}
