import UIKit
import Combine

final class HotelListViewController: UITableViewController {

    // MARK: - Dependencies

    private let viewModel: HotelListViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Coordinator callback

    var onSelectHotel: ((HotelListUIModel) -> Void)?

    // MARK: - Private

    private static let cellID = "HotelListCell"

    // MARK: - Init

    init(viewModel: HotelListViewModel) {
        self.viewModel = viewModel
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Hotels"
        tableView.register(HotelListCell.self, forCellReuseIdentifier: HotelListCell.reuseID)
        tableView.rowHeight = 72
        bindViewModel()
        Task { await viewModel.loadHotels() }
    }

    // MARK: - Bindings

    private func bindViewModel() {
        viewModel.$hotels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.tableView.reloadData() }
            .store(in: &cancellables)

        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                guard let self else { return }
                if loading {
                    let spinner = UIActivityIndicatorView(style: .medium)
                    spinner.startAnimating()
                    tableView.tableFooterView = spinner
                } else {
                    tableView.tableFooterView = nil
                }
            }
            .store(in: &cancellables)

        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] message in
                guard let self else { return }
                let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
            .store(in: &cancellables)
    }

    // MARK: - UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.hotels.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: HotelListCell.reuseID, for: indexPath) as! HotelListCell
        cell.configure(with: viewModel.hotels[indexPath.row])
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelectHotel?(viewModel.hotels[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let lastIndex = viewModel.hotels.count - 1
        guard indexPath.row == lastIndex else { return }
        Task { await viewModel.loadNextPage() }
    }
}

// MARK: - HotelListCell

private final class HotelListCell: UITableViewCell {
    static let reuseID = "HotelListCell"

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
        let stack = UIStackView(arrangedSubviews: [nameLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with model: HotelListUIModel) {
        nameLabel.text = model.name
        subtitleLabel.text = "\(model.location) · \(model.priceText) · \(model.rating)★"
    }
}
