import UIKit
import MelodifyDesignSystem

enum AppCardID {
    case music
    case chat
    case storyViewer
    case uberEats
    case dsCatalog
    case hotelBooking
}

private struct AppCard {
    let id: AppCardID
    let icon: String
    let title: String
    let subtitle: String
}

final class HomeViewController: UIViewController {
    var onCardTapped: ((AppCardID) -> Void)?

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = Spacing.md
        layout.minimumLineSpacing = Spacing.md
        layout.sectionInset = UIEdgeInsets(
            top: Spacing.lg, left: Spacing.md,
            bottom: Spacing.lg, right: Spacing.md
        )
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = MDSColor.surface
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(AppCardCell.self, forCellWithReuseIdentifier: AppCardCell.reuseID)
        cv.dataSource = self
        cv.delegate = self
        return cv
    }()

    private let cards: [AppCard] = [
        AppCard(id: .music,        icon: "music.note",         title: "Music",
                subtitle: "HLS streaming · AudioService · FetchPolicy"),
        AppCard(id: .chat,         icon: "message.fill",       title: "Chat",
                subtitle: "WebSocket mux · MessageContent · Send queue"),
        AppCard(id: .storyViewer,  icon: "play.circle.fill",   title: "Story Viewer",
                subtitle: "Three-view recycling · Prefetch · Auto-advance timer"),
        AppCard(id: .uberEats,     icon: "fork.knife",         title: "Uber Eats",
                subtitle: "SSE order tracking · Basket · Three-tier API"),
        AppCard(id: .dsCatalog,    icon: "paintpalette.fill",  title: "DS Catalog",
                subtitle: "MelodifyDesignSystem component browser"),
        AppCard(id: .hotelBooking, icon: "building.2.fill",    title: "Hotel Booking",
                subtitle: "ReservationService · Stripe facade · Offset pagination"),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Melodify"
        view.backgroundColor = MDSColor.surface
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }
}

extension HomeViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        cards.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AppCardCell.reuseID, for: indexPath) as! AppCardCell
        cell.configure(with: cards[indexPath.item])
        return cell
    }
}

extension HomeViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let totalHorizontalSpacing = Spacing.md * 3  // left inset + gap + right inset
        let width = floor((collectionView.bounds.width - totalHorizontalSpacing) / 2)
        return CGSize(width: width, height: width * 0.85)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onCardTapped?(cards[indexPath.item].id)
    }
}

private final class AppCardCell: UICollectionViewCell {
    static let reuseID = "AppCardCell"

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        contentView.backgroundColor = MDSColor.surfaceElevated
        contentView.layer.cornerRadius = Radius.lg
        contentView.layer.masksToBounds = true
        applyShadow(Elevation.low)

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = MDSColor.primary
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = Typography.title
        titleLabel.textColor = MDSColor.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = Typography.body
        subtitleLabel.textColor = MDSColor.textSecondary
        subtitleLabel.numberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        [iconView, titleLabel, subtitleLabel].forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Spacing.md),
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.md),
            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: Spacing.sm),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.md),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Spacing.sm),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Spacing.xs),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.md),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Spacing.sm),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -Spacing.sm),
        ])
    }

    func configure(with card: AppCard) {
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        iconView.image = UIImage(systemName: card.icon, withConfiguration: config)
        titleLabel.text = card.title
        subtitleLabel.text = card.subtitle
    }
}
