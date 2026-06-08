import UIKit
import Combine
import MelodifyDesignSystem

final class PlaylistDetailViewController: UIViewController {
    private let viewModel: PlaylistDetailViewModel
    private var cancellables = Set<AnyCancellable>()

    private let tableView = UITableView()
    private let loadingView: MDSLoadingView = {
        let v = MDSLoadingView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    init(viewModel: PlaylistDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = MDSColor.surface
        setupTableView()
        bindViewModel()
        viewModel.load()
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 56
        tableView.dataSource = self
        view.addSubview(tableView)
        view.addSubview(loadingView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func bindViewModel() {
        viewModel.$detail
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detail in
                self?.title = detail?.name
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                self?.loadingView.isHidden = !loading
                if loading { self?.loadingView.configure(with: MDSLoadingConfiguration()) }
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

extension PlaylistDetailViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.detail?.tracks.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        guard let track = viewModel.detail?.tracks[indexPath.row] else { return cell }
        var content = cell.defaultContentConfiguration()
        content.text = track.title
        content.secondaryText = "\(track.artist) · \(track.duration)"
        cell.contentConfiguration = content
        return cell
    }
}
