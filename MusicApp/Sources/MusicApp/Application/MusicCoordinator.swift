import UIKit
import CoreKit

/// Public entry point for the MusicApp module.
/// The host app creates this, calls start(), then pushes tabBarController onto its nav stack.
/// All internal dependency wiring happens here.
@MainActor
public final class MusicCoordinator {
    public private(set) lazy var tabBarController: UITabBarController = {
        let tab = UITabBarController()
        tab.viewControllers = [searchCoordinator.navigationController, homeCoordinator.navigationController]
        return tab
    }()

    private let searchCoordinator: SearchCoordinator
    private let homeCoordinator: HomeCoordinator

    public init(analytics: AnalyticsGatewayProtocol) {
        let client = APIClient()
        let localDataSource = TrackLocalDataSource()
        let trackRepository = TrackRepository(
            remoteDataSource: TrackRemoteDataSource(client: client),
            localDataSource: localDataSource
        )
        let playlistRepository = PlaylistRepository(
            remoteDataSource: PlaylistRemoteDataSource(client: client)
        )

        searchCoordinator = SearchCoordinator(trackRepository: trackRepository, analytics: analytics)
        homeCoordinator = HomeCoordinator(
            trackRepository: trackRepository,
            playlistRepository: playlistRepository,
            analytics: analytics
        )
    }

    public func start() {
        searchCoordinator.start()
        homeCoordinator.start()
    }

    @MainActor public func showTrackDetail(id: Int) {
        searchCoordinator.showTrackDetail(id: id)
    }

    @MainActor public func showPlaylistDetail(id: Int) {
        homeCoordinator.showPlaylistDetail(id: id)
    }

    @MainActor public func triggerSearch(query: String) {
        searchCoordinator.triggerSearch(query: query)
    }
}
