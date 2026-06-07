import UIKit
import Combine

public final class ConversationListViewController: UIViewController {
    var onSelectConversation: ((String) -> Void)?

    private let viewModel: ConversationListViewModel
    private var cancellables = Set<AnyCancellable>()

    private lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(ConversationCell.self, forCellReuseIdentifier: ConversationCell.reuseIdentifier)
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 72
        tv.delegate = self
        return tv
    }()

    private lazy var dataSource = UITableViewDiffableDataSource<Int, ConversationUIModel>(
        tableView: tableView
    ) { tableView, indexPath, model in
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ConversationCell.reuseIdentifier,
            for: indexPath
        ) as! ConversationCell
        cell.configure(with: model)
        return cell
    }

    init(viewModel: ConversationListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "Messages"
        view.backgroundColor = .systemBackground
        setupTableView()
        bindViewModel()
        viewModel.load()
    }

    private func setupTableView() {
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func bindViewModel() {
        viewModel.$conversations
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                var snapshot = NSDiffableDataSourceSnapshot<Int, ConversationUIModel>()
                snapshot.appendSections([0])
                snapshot.appendItems(items)
                self?.dataSource.apply(snapshot, animatingDifferences: true)
            }
            .store(in: &cancellables)
    }
}

extension ConversationListViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let model = dataSource.itemIdentifier(for: indexPath) else { return }
        onSelectConversation?(model.id)
    }
}
