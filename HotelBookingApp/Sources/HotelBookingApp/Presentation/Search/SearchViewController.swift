import UIKit
import SwiftUI
import Combine

final class SearchViewController: UIViewController {

    // MARK: - Dependencies

    private let viewModel: SearchViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Search Hotels"
        view.backgroundColor = .systemBackground
        embedSearchView()
        bindViewModel()
    }

    // MARK: - Private

    private func embedSearchView() {
        let searchView = SearchView(viewModel: viewModel)
        let host = UIHostingController(rootView: searchView)
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
                let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
            .store(in: &cancellables)
    }
}

// MARK: - SwiftUI SearchView (private)

private struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TextField("Destination", text: $viewModel.destination)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .onChange(of: viewModel.destination) { newValue in
                        viewModel.didChangeDestination(query: newValue)
                    }

                TextField("Check-in (YYYY-MM-DD)", text: $viewModel.checkIn)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                TextField("Check-out (YYYY-MM-DD)", text: $viewModel.checkOut)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Stepper("Guests: \(viewModel.guestCount)", value: $viewModel.guestCount, in: 1...10)
                    .padding(.horizontal)

                if viewModel.isLoading {
                    ProgressView()
                }

                if !viewModel.autocompleteResults.isEmpty {
                    List(viewModel.autocompleteResults) { result in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.name)
                                .font(.headline)
                            Text(result.location)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .listStyle(.plain)
                }

                Button(action: { viewModel.searchQuery() }) {
                    Text("Search")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
        }
    }
}
