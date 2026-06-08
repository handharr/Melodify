import UIKit
import Combine
import MelodifyDesignSystem

final class BasketViewController: UIViewController {
    private let viewModel: BasketViewModel
    private var cancellables = Set<AnyCancellable>()

    private lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.register(BasketItemCell.self, forCellReuseIdentifier: BasketItemCell.reuseID)
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 64
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let totalLabel: UILabel = {
        let l = UILabel()
        l.font = Typography.title
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let placeOrderButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Place Order"
        config.cornerStyle = .medium
        let b = UIButton(configuration: config)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    init(viewModel: BasketViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Basket"
        view.backgroundColor = MDSColor.surface
        setupLayout()
        tableView.dataSource = self
        placeOrderButton.addTarget(self, action: #selector(placeOrderTapped), for: .touchUpInside)
        bindViewModel()
        viewModel.load()
    }

    private func setupLayout() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        view.addSubview(totalLabel)
        view.addSubview(placeOrderButton)
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: totalLabel.topAnchor, constant: -16),

            totalLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            totalLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            totalLabel.bottomAnchor.constraint(equalTo: placeOrderButton.topAnchor, constant: -16),

            placeOrderButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            placeOrderButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            placeOrderButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            placeOrderButton.heightAnchor.constraint(equalToConstant: 50),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func bindViewModel() {
        viewModel.$basket
            .receive(on: DispatchQueue.main)
            .sink { [weak self] basket in
                self?.totalLabel.text = basket?.totalPrice
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                loading ? self?.activityIndicator.startAnimating() : self?.activityIndicator.stopAnimating()
                self?.placeOrderButton.isEnabled = !loading
            }
            .store(in: &cancellables)
    }

    @objc private func placeOrderTapped() { viewModel.placeOrder() }
}

extension BasketViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.basket?.items.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: BasketItemCell.reuseID, for: indexPath) as! BasketItemCell
        if let item = viewModel.basket?.items[indexPath.row] { cell.configure(with: item) }
        return cell
    }
}
