import UIKit
import Combine
import MelodifyDesignSystem

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

    private lazy var emptyStateView: MDSEmptyStateView = {
        let v = MDSEmptyStateView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        v.configure(with: MDSEmptyStateConfiguration(
            systemImageName: "bubble.left.and.bubble.right",
            title: "No Conversations",
            subtitle: "Your messages will appear here."
        ))
        return v
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
        view.backgroundColor = MDSColor.surface
        setupTableView()
        bindViewModel()
        viewModel.load()
    }

    private func setupTableView() {
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func bindViewModel() {
        viewModel.$conversations
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                guard let self else { return }
                var snapshot = NSDiffableDataSourceSnapshot<Int, ConversationUIModel>()
                snapshot.appendSections([0])
                snapshot.appendItems(items)
                dataSource.apply(snapshot, animatingDifferences: true)
                emptyStateView.isHidden = !items.isEmpty
                tableView.isHidden = items.isEmpty
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
