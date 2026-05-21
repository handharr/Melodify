import UserNotifications

// Schedules local notifications with deep link payloads — used for simulator testing.
// In production, the server sends the same payload via APNs.
final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func scheduleTrackNotification(trackId: Int, trackTitle: String) {
        schedule(
            identifier: "track-\(trackId)",
            title: "Now Trending",
            body: trackTitle,
            deepLink: "melodify://track/\(trackId)"
        )
    }

    func schedulePlaylistNotification(playlistId: Int, playlistName: String) {
        schedule(
            identifier: "playlist-\(playlistId)",
            title: "New Playlist for You",
            body: playlistName,
            deepLink: "melodify://playlist/\(playlistId)"
        )
    }

    private func schedule(identifier: String, title: String, body: String, deepLink: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["deep_link": deepLink]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
