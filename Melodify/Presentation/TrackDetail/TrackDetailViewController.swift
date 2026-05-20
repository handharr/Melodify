import UIKit

final class TrackDetailViewController: UIViewController {
    private let viewModel: TrackDetailViewModel

    private let artworkImageView = UIImageView()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let albumLabel = UILabel()
    private let genreLabel = UILabel()
    private let durationLabel = UILabel()

    init(viewModel: TrackDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = viewModel.title
        setupLayout()
        populate()
    }

    private func setupLayout() {
        artworkImageView.contentMode = .scaleAspectFit
        artworkImageView.clipsToBounds = true
        artworkImageView.backgroundColor = .systemGray5
        artworkImageView.layer.cornerRadius = 8
        artworkImageView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.numberOfLines = 0

        artistLabel.font = .systemFont(ofSize: 17)
        artistLabel.textColor = .secondaryLabel

        albumLabel.font = .systemFont(ofSize: 15)
        albumLabel.textColor = .secondaryLabel

        genreLabel.font = .systemFont(ofSize: 14)
        genreLabel.textColor = .tertiaryLabel

        durationLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        durationLabel.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [titleLabel, artistLabel, albumLabel, genreLabel, durationLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(artworkImageView)
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            artworkImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            artworkImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            artworkImageView.widthAnchor.constraint(equalToConstant: 200),
            artworkImageView.heightAnchor.constraint(equalToConstant: 200),

            stack.topAnchor.constraint(equalTo: artworkImageView.bottomAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func populate() {
        titleLabel.text = viewModel.title
        artistLabel.text = viewModel.artist
        albumLabel.text = viewModel.album
        genreLabel.text = viewModel.genre
        durationLabel.text = viewModel.duration

        guard let url = viewModel.artworkURL else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else { return }
            artworkImageView.image = image
        }
    }
}
