import UIKit
import CoreKit

public final class HotelBookingCoordinator {

    // MARK: - Public interface

    public private(set) var tabBarController: UITabBarController

    // MARK: - Private nav controllers

    private var searchNavController: UINavigationController
    private var reservationNavController: UINavigationController

    // MARK: - Services (coordinator-scoped singletons)

    private let reservationService: ReservationService
    private let imageService: ImageService
    private let paymentService: PaymentService

    // MARK: - Use Cases

    private let searchHotelsUseCase: SearchHotelsUseCaseProtocol
    private let fetchHotelDetailUseCase: FetchHotelDetailUseCaseProtocol
    private let fetchAmenitiesUseCase: FetchAmenitiesUseCaseProtocol
    private let createReservationUseCase: CreateReservationUseCaseProtocol
    private let fetchReservationsUseCase: FetchReservationsUseCaseProtocol

    // MARK: - Data layer (held to satisfy strong-ref requirements)

    private let hotelLocalDataSource: HotelLocalDataSource

    // MARK: - Init

    public init() {
        // ── Networking ──────────────────────────────────────────────────
        let client = APIClient()

        // ── Hotel ───────────────────────────────────────────────────────
        let hotelRemote = HotelRemoteDataSource(client: client)
        let hotelLocal  = HotelLocalDataSource()
        let hotelRepository = HotelRepository(
            remoteDataSource: hotelRemote,
            localDataSource: hotelLocal
        )

        // ── Reservation ─────────────────────────────────────────────────
        let reservationRemote = ReservationRemoteDataSource(client: client)
        let reservationLocal  = ReservationLocalDataSource()
        let reservationRepository = ReservationRepository(
            remoteDataSource: reservationRemote,
            localDataSource: reservationLocal
        )

        // ── Amenity ─────────────────────────────────────────────────────
        let amenityRemote = AmenityRemoteDataSource(client: client)
        let amenityLocal  = AmenityLocalDataSource()
        let amenityRepository = AmenityRepository(
            remoteDataSource: amenityRemote,
            localDataSource: amenityLocal
        )

        // ── Image ────────────────────────────────────────────────────────
        let diskDataSource  = ImageDiskDataSource()
        let imageLocalDS    = ImageLocalDataSource()
        let imageRepository = ImageRepository(
            diskDataSource: diskDataSource,
            localDataSource: imageLocalDS,
            client: client
        )

        // ── Payment ──────────────────────────────────────────────────────
        let paymentRemote     = PaymentRemoteDataSource(client: client)
        let paymentRepository = PaymentRepository(remoteDataSource: paymentRemote)

        // ── Services ─────────────────────────────────────────────────────
        let reservationSvc    = ReservationService()
        let imageSvc          = ImageService(imageRepository: imageRepository)
        let stripeGateway     = StripePaymentGateway()
        let processPaymentUC  = ProcessPaymentUseCase(repository: paymentRepository)
        let paymentSvc        = PaymentService(
            gateway: stripeGateway,
            processPaymentUseCase: processPaymentUC
        )

        // ── Use Cases ────────────────────────────────────────────────────
        let searchHotelsUC      = SearchHotelsUseCase(repository: hotelRepository)
        let fetchHotelDetailUC  = FetchHotelDetailUseCase(repository: hotelRepository)
        let fetchAmenitiesUC    = FetchAmenitiesUseCase(repository: amenityRepository)
        let createReservationUC = CreateReservationUseCase(repository: reservationRepository)
        let fetchReservationsUC = FetchReservationsUseCase(repository: reservationRepository)

        // ── Assign ───────────────────────────────────────────────────────
        self.reservationService       = reservationSvc
        self.imageService             = imageSvc
        self.paymentService           = paymentSvc
        self.searchHotelsUseCase      = searchHotelsUC
        self.fetchHotelDetailUseCase  = fetchHotelDetailUC
        self.fetchAmenitiesUseCase    = fetchAmenitiesUC
        self.createReservationUseCase = createReservationUC
        self.fetchReservationsUseCase = fetchReservationsUC
        self.hotelLocalDataSource     = hotelLocal

        // ── Navigation placeholders (populated in start()) ───────────────
        self.searchNavController      = UINavigationController()
        self.reservationNavController = UINavigationController()
        self.tabBarController         = UITabBarController()
    }

    // MARK: - Start

    @MainActor public func start() {
        // 1. Prefetch amenities in the background
        Task { [weak self] in
            guard let self else { return }
            try? await fetchAmenitiesUseCase.execute(request: FetchAmenitiesRequest(query: (), policy: .fresh))
        }

        // 2. Build search tab
        let searchTab = buildSearchTab()
        searchNavController = searchTab

        // 3. Build reservations tab
        let reservationListVM = ReservationListViewModel(
            fetchReservationsUseCase: fetchReservationsUseCase
        )
        let reservationListVC = ReservationListViewController(viewModel: reservationListVM)
        reservationListVC.tabBarItem = UITabBarItem(
            title: "My Reservations",
            image: UIImage(systemName: "list.bullet"),
            tag: 1
        )
        reservationNavController = UINavigationController(rootViewController: reservationListVC)

        // 4. Assemble tab bar
        tabBarController.viewControllers = [searchNavController, reservationNavController]
    }

    // MARK: - Search Tab Builder

    @MainActor private func buildSearchTab() -> UINavigationController {
        let searchVM = SearchViewModel(
            searchHotelsUseCase: searchHotelsUseCase,
            hotelLocalDataSource: hotelLocalDataSource
        )

        searchVM.onSearch = { [weak self] listings in
            guard let self else { return }
            // Use the first listing's search params as the base query for the list
            guard let first = listings.first else { return }
            let query = SearchHotelsQuery(
                destination: first.location,
                checkIn: "",
                checkOut: "",
                guestCount: 1
            )
            pushHotelList(query: query, into: searchNavController)
        }

        let searchVC = SearchViewController(viewModel: searchVM)
        searchVC.tabBarItem = UITabBarItem(
            title: "Search",
            image: UIImage(systemName: "magnifyingglass"),
            tag: 0
        )

        return UINavigationController(rootViewController: searchVC)
    }

    // MARK: - Navigation helpers

    @MainActor private func pushHotelList(
        query: SearchHotelsQuery,
        into nav: UINavigationController
    ) {
        let vm = HotelListViewModel(
            searchHotelsUseCase: searchHotelsUseCase,
            query: query
        )

        let vc = HotelListViewController(viewModel: vm)

        vc.onSelectHotel = { [weak self, weak nav] hotel in
            guard let self, let nav else { return }
            self.pushHotelDetail(hotelId: hotel.id, into: nav)
        }

        nav.pushViewController(vc, animated: true)
    }

    @MainActor private func pushHotelDetail(
        hotelId: String,
        into nav: UINavigationController
    ) {
        let vm = HotelDetailViewModel(
            hotelId: hotelId,
            fetchHotelDetailUseCase: fetchHotelDetailUseCase,
            imageService: imageService
        )

        vm.onReserve = { [weak self, weak nav] hotel in
            guard let self, let nav else { return }
            self.pushReservation(hotel: hotel, into: nav)
        }

        let vc = HotelDetailViewController(viewModel: vm)
        nav.pushViewController(vc, animated: true)
    }

    @MainActor private func pushReservation(
        hotel: Hotel,
        into nav: UINavigationController
    ) {
        let vm = ReservationViewModel(
            hotel: hotel,
            createReservationUseCase: createReservationUseCase,
            reservationService: reservationService
        )

        vm.onReserved = { [weak self, weak nav] reservation in
            guard let self, let nav else { return }
            self.pushPayment(reservation: reservation, into: nav)
        }

        let vc = ReservationViewController(viewModel: vm)
        nav.pushViewController(vc, animated: true)
    }

    @MainActor private func pushPayment(
        reservation: Reservation,
        into nav: UINavigationController
    ) {
        let vm = PaymentViewModel(
            reservationId: reservation.reservationId,
            paymentService: paymentService
        )

        vm.onPaymentComplete = { [weak nav] in
            nav?.popToRootViewController(animated: true)
        }

        let vc = PaymentViewController(viewModel: vm)
        nav.pushViewController(vc, animated: true)
    }
}
