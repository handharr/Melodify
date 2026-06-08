import UIKit
import Combine
import MelodifyDesignSystem

final class OrderStatusViewController: UIViewController {
    private let viewModel: OrderStatusViewModel
    private var cancellables = Set<AnyCancellable>()

    private let mapView = OrderMapView()
    private let statusLabel: UILabel = {
        let l = UILabel()
        l.font = Typography.title
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    init(viewModel: OrderStatusViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Order Status"
        view.backgroundColor = MDSColor.surface
        setupLayout()
        bindViewModel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.startTracking()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Closes the SSE connection immediately — prevents battery drain and stale server connections.
        viewModel.stopTracking()
    }

    private func setupLayout() {
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6),

            statusLabel.topAnchor.constraint(equalTo: mapView.bottomAnchor, constant: 24),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func bindViewModel() {
        viewModel.$order
            .receive(on: DispatchQueue.main)
            .sink { [weak self] order in
                self?.statusLabel.text = order.statusText
                self?.mapView.updateCourierLocation(order.courierLocation)
            }
            .store(in: &cancellables)
    }
}
