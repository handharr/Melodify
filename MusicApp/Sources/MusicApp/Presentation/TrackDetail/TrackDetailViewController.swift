import UIKit
import Combine
import MelodifyDesignSystem

final class TrackDetailViewController: UIViewController {
    private let viewModel: TrackDetailViewModel
    private var cancellables = Set<AnyCancellable>()

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
        view.backgroundColor = MDSColor.surface
        setupLayout()
        bindViewModel()
        viewModel.load()
    }

    private func setupLayout() {
        artworkImageView.contentMode = .scaleAspectFit
        artworkImageView.clipsToBounds = true
        artworkImageView.backgroundColor = MDSColor.surfaceElevated
        artworkImageView.layer.cornerRadius = Radius.md
        artworkImageView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = Typography.display
        titleLabel.numberOfLines = 0
        artistLabel.font = Typography.title
        artistLabel.textColor = MDSColor.textSecondary
        albumLabel.font = Typography.body
        albumLabel.textColor = MDSColor.textSecondary
        genreLabel.font = Typography.caption
        genreLabel.textColor = MDSColor.textDisabled
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        durationLabel.textColor = MDSColor.textSecondary

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

    private func bindViewModel() {
        viewModel.$detail
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] detail in self?.populate(with: detail) }
            .store(in: &cancellables)
    }

    private func populate(with detail: TrackDetailUIModel) {
        title = detail.title
        titleLabel.text = detail.title
        artistLabel.text = detail.artist
        albumLabel.text = detail.album
        genreLabel.text = detail.genre
        durationLabel.text = detail.duration

        guard let url = detail.artworkURL else { return }
        Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else { return }
            self?.artworkImageView.image = image
        }
    }
}
