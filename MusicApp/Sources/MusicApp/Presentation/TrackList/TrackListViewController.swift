import UIKit
import Combine
import MelodifyDesignSystem

@MainActor
protocol TrackListDelegate: AnyObject {
    func didSelectTrack(_ track: TrackUIModel)
}

final class TrackListViewController: UIViewController {
    weak var delegate: TrackListDelegate?

    private let viewModel: TrackListViewModel
    private var cancellables = Set<AnyCancellable>()

    private let tableView = UITableView()
    private let searchController = UISearchController(searchResultsController: nil)

    private let loadingView: MDSLoadingView = {
        let v = MDSLoadingView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private let emptyStateView: MDSEmptyStateView = {
        let v = MDSEmptyStateView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        v.configure(with: MDSEmptyStateConfiguration(
            systemImageName: "music.note.list",
            title: "No Results",
            subtitle: "Search for a track to get started."
        ))
        return v
    }()

    init(viewModel: TrackListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Music"
        view.backgroundColor = MDSColor.surface
        setupTableView()
        setupSearch()
        setupOverlays()
        bindViewModel()
        viewModel.search(query: "arctic monkeys")
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(TrackCell.self, forCellReuseIdentifier: TrackCell.reuseID)
        tableView.rowHeight = 80
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupSearch() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search tracks"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
    }

    private func setupOverlays() {
        view.addSubview(loadingView)
        view.addSubview(emptyStateView)
        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingView.widthAnchor.constraint(equalToConstant: 80),
            loadingView.heightAnchor.constraint(equalToConstant: 80),

            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func bindViewModel() {
        viewModel.$tracks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tracks in
                guard let self else { return }
                tableView.reloadData()
                emptyStateView.isHidden = !tracks.isEmpty || viewModel.isLoading
            }
            .store(in: &cancellables)

        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                guard let self else { return }
                loadingView.isHidden = !loading
                if loading {
                    loadingView.configure(with: MDSLoadingConfiguration())
                    emptyStateView.isHidden = true
                } else {
                    emptyStateView.isHidden = !viewModel.tracks.isEmpty
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
}

extension TrackListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.tracks.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TrackCell.reuseID, for: indexPath) as! TrackCell
        cell.configure(with: viewModel.tracks[indexPath.row])
        return cell
    }
}

extension TrackListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        delegate?.didSelectTrack(viewModel.tracks[indexPath.row])
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.height
        if offsetY > contentHeight - frameHeight - 100 {
            viewModel.loadNextPage()
        }
    }
}

extension TrackListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let query = searchController.searchBar.text, query.count > 2 else { return }
        viewModel.search(query: query)
    }
}
