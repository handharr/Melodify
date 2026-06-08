import UIKit
import Combine
import MelodifyDesignSystem

final class ReservationListViewController: UITableViewController {

    // MARK: - Dependencies

    private let viewModel: ReservationListViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(viewModel: ReservationListViewModel) {
        self.viewModel = viewModel
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "My Reservations"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ReservationCell")
        tableView.rowHeight = 64
        bindViewModel()
        Task { await viewModel.load() }
    }

    // MARK: - Bindings

    private func bindViewModel() {
        viewModel.$reservations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.tableView.reloadData() }
            .store(in: &cancellables)

        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                guard let self else { return }
                if loading {
                    let footer = MDSLoadingView()
                    footer.configure(with: MDSLoadingConfiguration())
                    footer.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 56)
                    tableView.tableFooterView = footer
                } else {
                    tableView.tableFooterView = nil
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.reservations.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ReservationCell", for: indexPath)
        let item = viewModel.reservations[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = item.hotelName
        content.secondaryText = "\(item.checkIn) – \(item.checkOut)"
        cell.contentConfiguration = content
        return cell
    }
}
