import UIKit
import MelodifyDesignSystem

final class TrackCell: UITableViewCell {
    static let reuseID = "TrackCell"

    private let rowView: MDSTrackRowView = {
        let v = MDSTrackRowView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(rowView)
        NSLayoutConstraint.activate([
            rowView.topAnchor.constraint(equalTo: contentView.topAnchor),
            rowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rowView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with track: TrackUIModel) {
        rowView.configure(with: MDSTrackRowConfiguration(
            title: track.title,
            subtitle: track.artist,
            duration: track.duration,
            artworkURL: track.artworkURL
        ))
    }
}
