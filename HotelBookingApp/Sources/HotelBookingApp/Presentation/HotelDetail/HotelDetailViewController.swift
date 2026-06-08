import UIKit
import SwiftUI
import Combine

final class HotelDetailViewController: UIViewController {

    // MARK: - Dependencies

    private let viewModel: HotelDetailViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(viewModel: HotelDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Hotel Detail"
        view.backgroundColor = .systemBackground
        embedDetailView()
        bindViewModel()
        Task { await viewModel.load() }
    }

    // MARK: - Private

    private func embedDetailView() {
        let detailView = HotelDetailView(viewModel: viewModel)
        let host = UIHostingController(rootView: detailView)
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

// MARK: - SwiftUI HotelDetailView (private)

private struct HotelDetailView: View {
    @ObservedObject var viewModel: HotelDetailViewModel

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.detail == nil {
                ProgressView("Loading…")
            } else if let detail = viewModel.detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // Amenities
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amenities")
                                .font(.headline)
                            ForEach(detail.amenityNames, id: \.self) { name in
                                Text("• \(name)")
                                    .font(.subheadline)
                            }
                        }
                        .padding(.horizontal)

                        Divider()

                        // Rooms
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rooms")
                                .font(.headline)
                            ForEach(detail.rooms) { room in
                                HStack {
                                    Text("Room \(room.id)")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(room.bedsText)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.horizontal)

                        // Reserve CTA
                        Button(action: { viewModel.reserve() }) {
                            Text("Reserve")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding()
                    }
                    .padding(.top)
                }
            } else {
                Text("No hotel details available.")
                    .foregroundColor(.secondary)
            }
        }
    }
}
