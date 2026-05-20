import Foundation

enum MockSession {
    static func make() -> URLSession {
        MockURLProtocol.mockResponses = [
            "/api/v1/playlists": (200, MockResponses.playlists),
            "/api/v1/playlists/4": (200, MockResponses.updatePlaylist)
        ]

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
