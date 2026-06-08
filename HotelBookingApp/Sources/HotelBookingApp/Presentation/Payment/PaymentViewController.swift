import UIKit
import SwiftUI
import Combine

final class PaymentViewController: UIViewController {

    // MARK: - Dependencies

    private let viewModel: PaymentViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(viewModel: PaymentViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Payment"
        view.backgroundColor = .systemBackground
        embedPaymentView()
        bindViewModel()
    }

    // MARK: - Private

    private func embedPaymentView() {
        let paymentView = PaymentView(viewModel: viewModel)
        let host = UIHostingController(rootView: paymentView)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    private func bindViewModel() {
        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] message in
                guard let self else { return }
                let alert = UIAlertController(title: "Payment Failed", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
            .store(in: &cancellables)
    }
}

// MARK: - SwiftUI PaymentView (private)

private struct PaymentView: View {
    @ObservedObject var viewModel: PaymentViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Payment")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Tap to Pay")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if viewModel.isLoading {
                ProgressView("Processing payment…")
                    .padding()
            } else {
                Button(action: {
                    Task { await viewModel.pay() }
                }) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                        Text("Tap to Pay")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            }

            Spacer()
        }
    }
}
