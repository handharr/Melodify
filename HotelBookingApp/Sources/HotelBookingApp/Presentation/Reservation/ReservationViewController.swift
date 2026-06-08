import UIKit
import SwiftUI
import Combine

final class ReservationViewController: UIViewController {

    // MARK: - Dependencies

    private let viewModel: ReservationViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(viewModel: ReservationViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Reserve Room"
        view.backgroundColor = .systemBackground
        embedReservationView()
        bindViewModel()
    }

    // MARK: - Private

    private func embedReservationView() {
        let reservationView = ReservationView(viewModel: viewModel)
        let host = UIHostingController(rootView: reservationView)
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

// MARK: - SwiftUI ReservationView (private)

private struct ReservationView: View {
    @ObservedObject var viewModel: ReservationViewModel

    var body: some View {
        VStack(spacing: 20) {

            // Countdown timer
            Text("Hold expires in: \(viewModel.timeRemainingText)")
                .font(.title3)
                .fontWeight(.semibold)
                .padding()
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(8)

            // Room picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Rooms")
                    .font(.headline)
                    .padding(.horizontal)

                List {
                    ForEach(viewModel.availableRooms, id: \.self) { roomId in
                        HStack {
                            Text("Room \(roomId)")
                            Spacer()
                            if viewModel.selectedRoomIds.contains(roomId) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.toggleRoom(roomId)
                        }
                    }
                }
                .listStyle(.plain)
                .frame(height: 200)
            }

            if viewModel.isLoading {
                ProgressView("Processing…")
            }

            // Proceed to Payment CTA
            Button(action: {
                Task { await viewModel.reserve() }
            }) {
                Text("Proceed to Payment")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.selectedRoomIds.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(viewModel.selectedRoomIds.isEmpty || viewModel.isLoading)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top)
    }
}
