import UIKit
import SwiftUI
import MelodifyDesignSystem

final class DSCatalogViewController: UIViewController {

    // MARK: - Model

    private struct CatalogItem {
        let title: String
        let makePreview: () -> UIView
    }

    private struct CatalogSection {
        let title: String
        let items: [CatalogItem]
    }

    // MARK: - State

    private lazy var sections: [CatalogSection] = makeSections()
    // Pre-built cells keyed by [section][row] — never reconfigured, never reused with different content
    private lazy var cells: [[UITableViewCell]] = sections.map { section in
        section.items.map { item in
            let cell = CatalogCell()
            cell.configure(title: item.title, preview: item.makePreview())
            return cell
        }
    }

    // MARK: - UI

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 120
        return tv
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "DS Catalog"
        view.backgroundColor = MDSColor.surface
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "circle.lefthalf.filled"),
            style: .plain,
            target: self,
            action: #selector(toggleAppearance)
        )
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Light / Dark

    @objc private func toggleAppearance() {
        overrideUserInterfaceStyle = overrideUserInterfaceStyle == .dark ? .light : .dark
    }

    // MARK: - Section factory

    private func makeSections() -> [CatalogSection] {
        [
            CatalogSection(title: "Tokens", items: [
                CatalogItem(title: "Color", makePreview: makeColorPreview),
                CatalogItem(title: "Typography", makePreview: makeTypographyPreview),
                CatalogItem(title: "Spacing", makePreview: makeSpacingPreview),
                CatalogItem(title: "Radius", makePreview: makeRadiusPreview),
                CatalogItem(title: "Elevation", makePreview: makeElevationPreview),
            ]),
            CatalogSection(title: "UIKit Components", items: [
                CatalogItem(title: "MDSAvatarView", makePreview: makeAvatarPreview),
                CatalogItem(title: "MDSBadgeView", makePreview: makeBadgePreview),
                CatalogItem(title: "MDSLoadingView", makePreview: makeLoadingPreview),
                CatalogItem(title: "MDSMessageBubble", makePreview: makeMessageBubblePreview),
                CatalogItem(title: "MDSAudioPlayerView", makePreview: makeAudioPlayerPreview),
                CatalogItem(title: "MDSPrimaryButton", makePreview: makePrimaryButtonPreview),
                CatalogItem(title: "MDSEmptyStateView", makePreview: makeEmptyStatePreview),
            ]),
            CatalogSection(title: "SwiftUI Components", items: [
                CatalogItem(title: "MDSButton", makePreview: makeSUIButtonPreview),
                CatalogItem(title: "MDSAvatar", makePreview: makeSUIAvatarPreview),
                CatalogItem(title: "MDSEmptyState", makePreview: makeSUIEmptyStatePreview),
                CatalogItem(title: "MDSBadge", makePreview: makeSUIBadgePreview),
                CatalogItem(title: "MDSLoadingOverlay", makePreview: makeSUILoadingOverlayPreview),
            ]),
        ]
    }
}

// MARK: - UITableViewDataSource

extension DSCatalogViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].items.count }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].title }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        cells[indexPath.section][indexPath.row]
    }
}

// MARK: - Token Previews

private extension DSCatalogViewController {
    func makeColorPreview() -> UIView {
        let tokens: [(String, UIColor)] = [
            ("primary", MDSColor.primary),
            ("primaryVariant", MDSColor.primaryVariant),
            ("surface", MDSColor.surface),
            ("surfaceElevated", MDSColor.surfaceElevated),
            ("error", MDSColor.error),
            ("warning", MDSColor.warning),
            ("success", MDSColor.success),
        ]
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Spacing.sm
        stack.alignment = .center
        tokens.forEach { name, color in
            let swatch = UIView()
            swatch.backgroundColor = color
            swatch.layer.cornerRadius = Radius.xs
            swatch.layer.borderWidth = 0.5
            swatch.layer.borderColor = UIColor.separator.cgColor
            swatch.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                swatch.widthAnchor.constraint(equalToConstant: 28),
                swatch.heightAnchor.constraint(equalToConstant: 28),
            ])
            let label = UILabel()
            label.text = name
            label.font = .systemFont(ofSize: 9)
            label.textColor = MDSColor.textSecondary
            label.textAlignment = .center
            let col = UIStackView(arrangedSubviews: [swatch, label])
            col.axis = .vertical
            col.spacing = 2
            col.alignment = .center
            stack.addArrangedSubview(col)
        }
        return stack
    }

    func makeTypographyPreview() -> UIView {
        let pairs: [(String, UIFont)] = [
            ("Display", Typography.display),
            ("Title", Typography.title),
            ("Body", Typography.body),
            ("Caption", Typography.caption),
        ]
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Spacing.xs
        pairs.forEach { name, font in
            let label = UILabel()
            label.text = "\(name) — Aa Bb Cc"
            label.font = font
            label.textColor = MDSColor.textPrimary
            stack.addArrangedSubview(label)
        }
        return stack
    }

    func makeSpacingPreview() -> UIView {
        let tokens: [(String, CGFloat)] = [
            ("xs\n4pt", Spacing.xs),
            ("sm\n8pt", Spacing.sm),
            ("md\n16pt", Spacing.md),
            ("lg\n24pt", Spacing.lg),
            ("xl\n32pt", Spacing.xl),
        ]
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Spacing.sm
        stack.alignment = .bottom
        tokens.forEach { name, size in
            let box = UIView()
            box.backgroundColor = MDSColor.primary.withAlphaComponent(0.25)
            box.layer.cornerRadius = Radius.xs
            box.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                box.widthAnchor.constraint(equalToConstant: size),
                box.heightAnchor.constraint(equalToConstant: size),
            ])
            let label = UILabel()
            label.text = name
            label.font = .systemFont(ofSize: 9)
            label.textColor = MDSColor.textSecondary
            label.textAlignment = .center
            label.numberOfLines = 2
            let col = UIStackView(arrangedSubviews: [box, label])
            col.axis = .vertical
            col.spacing = Spacing.xs
            col.alignment = .center
            stack.addArrangedSubview(col)
        }
        return stack
    }

    func makeRadiusPreview() -> UIView {
        let tokens: [(String, CGFloat)] = [
            ("xs\n4", Radius.xs),
            ("sm\n8", Radius.sm),
            ("md\n12", Radius.md),
            ("lg\n16", Radius.lg),
            ("full\n∞", Radius.full),
        ]
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Spacing.md
        stack.alignment = .center
        tokens.forEach { name, radius in
            let box = UIView()
            box.backgroundColor = MDSColor.primary.withAlphaComponent(0.15)
            box.layer.cornerRadius = min(radius, 24)
            box.layer.borderWidth = 1.5
            box.layer.borderColor = MDSColor.primary.cgColor
            box.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                box.widthAnchor.constraint(equalToConstant: 48),
                box.heightAnchor.constraint(equalToConstant: 48),
            ])
            let label = UILabel()
            label.text = name
            label.font = .systemFont(ofSize: 9)
            label.textColor = MDSColor.textSecondary
            label.textAlignment = .center
            label.numberOfLines = 2
            let col = UIStackView(arrangedSubviews: [box, label])
            col.axis = .vertical
            col.spacing = Spacing.xs
            col.alignment = .center
            stack.addArrangedSubview(col)
        }
        return stack
    }

    func makeElevationPreview() -> UIView {
        let tokens: [(String, ShadowToken)] = [
            ("low", Elevation.low),
            ("mid", Elevation.mid),
            ("high", Elevation.high),
        ]
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Spacing.xl
        stack.alignment = .center
        tokens.forEach { name, shadow in
            let box = UIView()
            box.backgroundColor = MDSColor.surfaceElevated
            box.layer.cornerRadius = Radius.md
            box.applyShadow(shadow)
            box.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                box.widthAnchor.constraint(equalToConstant: 60),
                box.heightAnchor.constraint(equalToConstant: 40),
            ])
            let label = UILabel()
            label.text = name
            label.font = Typography.caption
            label.textColor = MDSColor.textSecondary
            label.textAlignment = .center
            let col = UIStackView(arrangedSubviews: [box, label])
            col.axis = .vertical
            col.spacing = Spacing.sm
            col.alignment = .center
            stack.addArrangedSubview(col)
        }
        return stack
    }
}

// MARK: - UIKit Component Previews

private extension DSCatalogViewController {
    func makeAvatarPreview() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Spacing.lg
        stack.alignment = .center
        [MDSAvatarSize.small, .medium, .large].forEach { size in
            let avatar = MDSAvatarView()
            avatar.configure(with: MDSAvatarConfiguration(name: "Ada Lovelace", imageURL: nil, size: size))
            let label = UILabel()
            label.text = "\(size)"
            label.font = Typography.caption
            label.textColor = MDSColor.textSecondary
            label.textAlignment = .center
            let col = UIStackView(arrangedSubviews: [avatar, label])
            col.axis = .vertical
            col.spacing = Spacing.xs
            col.alignment = .center
            stack.addArrangedSubview(col)
        }
        return stack
    }

    func makeBadgePreview() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Spacing.xl
        stack.alignment = .center
        [(0, "zero"), (5, "count"), (100, "capped")].forEach { count, label in
            let badge = MDSBadgeView()
            badge.configure(with: MDSBadgeConfiguration(count: count))
            let lbl = UILabel()
            lbl.text = label
            lbl.font = Typography.caption
            lbl.textColor = MDSColor.textSecondary
            lbl.textAlignment = .center
            let col = UIStackView(arrangedSubviews: [badge, lbl])
            col.axis = .vertical
            col.spacing = Spacing.xs
            col.alignment = .center
            stack.addArrangedSubview(col)
        }
        return stack
    }

    func makeLoadingPreview() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Spacing.xl
        stack.alignment = .center
        let inlineView = MDSLoadingView()
        inlineView.configure(with: MDSLoadingConfiguration(variant: .inline, message: "Loading…"))
        let inlineLbl = UILabel()
        inlineLbl.text = "inline"
        inlineLbl.font = Typography.caption
        inlineLbl.textColor = MDSColor.textSecondary
        inlineLbl.textAlignment = .center
        let inlineCol = UIStackView(arrangedSubviews: [inlineView, inlineLbl])
        inlineCol.axis = .vertical
        inlineCol.spacing = Spacing.xs
        inlineCol.alignment = .center
        stack.addArrangedSubview(inlineCol)
        return stack
    }

    func makeMessageBubblePreview() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Spacing.sm
        stack.alignment = .fill
        let outgoing = MDSMessageBubble()
        outgoing.configure(with: MDSMessageBubbleConfiguration(
            text: "Hey! How's it going?",
            variant: .outgoing,
            meta: "10:30 · ✓✓"
        ))
        let incoming = MDSMessageBubble()
        incoming.configure(with: MDSMessageBubbleConfiguration(
            text: "All good, working on Melodify 🎵",
            variant: .incoming,
            meta: "10:31"
        ))
        stack.addArrangedSubview(outgoing)
        stack.addArrangedSubview(incoming)
        return stack
    }

    func makeAudioPlayerPreview() -> UIView {
        let player = MDSAudioPlayerView()
        player.configure(with: MDSAudioPlayerConfiguration(
            duration: "0:42",
            isPlaying: false,
            variant: .incoming
        ))
        return player
    }

    func makePrimaryButtonPreview() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Spacing.md
        stack.alignment = .center
        let enabled = MDSPrimaryButton()
        enabled.configure(with: MDSPrimaryButtonConfiguration(title: "Play", isEnabled: true, isLoading: false))
        let disabled = MDSPrimaryButton()
        disabled.configure(with: MDSPrimaryButtonConfiguration(title: "Disabled", isEnabled: false, isLoading: false))
        let loading = MDSPrimaryButton()
        loading.configure(with: MDSPrimaryButtonConfiguration(title: "Loading", isEnabled: true, isLoading: true))
        [enabled, disabled, loading].forEach { stack.addArrangedSubview($0) }
        return stack
    }

    func makeEmptyStatePreview() -> UIView {
        let view = MDSEmptyStateView()
        view.configure(with: MDSEmptyStateConfiguration(
            systemImageName: "music.note.list",
            title: "No Tracks",
            subtitle: "Search for something to get started",
            buttonTitle: "Browse"
        ))
        return view
    }
}

// MARK: - SwiftUI Component Previews

private extension DSCatalogViewController {
    func makeSUIButtonPreview() -> UIView {
        let view = HStack(spacing: 12) {
            Button("Filled")  {}.buttonStyle(MDSButtonStyle(variant: .filled))
            Button("Outlined"){}.buttonStyle(MDSButtonStyle(variant: .outlined))
        }.padding()
        return UIHostingView(rootView: view)
    }

    func makeSUIAvatarPreview() -> UIView {
        let view = HStack(spacing: 16) {
            MDSAvatar(name: "Taylor Swift", imageURL: nil, size: .small)
            MDSAvatar(name: "Taylor Swift", imageURL: nil, size: .medium)
            MDSAvatar(name: "Taylor Swift", imageURL: nil, size: .large)
        }.padding()
        return UIHostingView(rootView: view)
    }

    func makeSUIEmptyStatePreview() -> UIView {
        let view = MDSEmptyState(
            systemImageName: "waveform.slash",
            title: "No Messages",
            subtitle: "Start a conversation",
            actionTitle: "New Chat",
            action: {}
        ).padding()
        return UIHostingView(rootView: view)
    }

    func makeSUIBadgePreview() -> UIView {
        let view = HStack(spacing: 24) {
            Image(systemName: "bell.fill").mdsBadge(count: 0)
            Image(systemName: "bell.fill").mdsBadge(count: 3)
            Image(systemName: "bell.fill").mdsBadge(count: 99)
        }
        .font(.title2)
        .padding()
        return UIHostingView(rootView: view)
    }

    func makeSUILoadingOverlayPreview() -> UIView {
        let view = ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(MDSColor.surfaceElevated))
                .frame(height: 100)
            MDSLoadingOverlay()
        }
        .frame(maxWidth: .infinity)
        .padding()
        return UIHostingView(rootView: view)
    }
}

// MARK: - CatalogCell

private final class CatalogCell: UITableViewCell {
    private let nameLabel = UILabel()
    private let previewContainer = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        nameLabel.font = Typography.title
        nameLabel.textColor = MDSColor.textPrimary
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        previewContainer.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(nameLabel)
        contentView.addSubview(previewContainer)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Spacing.md),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.md),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Spacing.md),

            previewContainer.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: Spacing.sm),
            previewContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.md),
            previewContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Spacing.md),
            previewContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Spacing.md),
        ])
    }

    required init?(coder: NSCoder) { nil }

    func configure(title: String, preview: UIView) {
        nameLabel.text = title
        preview.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(preview)
        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: previewContainer.topAnchor),
            preview.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            preview.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor),
            // trailing is `lessThanOrEqualTo` so intrinsic-width previews (stacks) don't stretch
            preview.trailingAnchor.constraint(lessThanOrEqualTo: previewContainer.trailingAnchor),
        ])
    }
}
