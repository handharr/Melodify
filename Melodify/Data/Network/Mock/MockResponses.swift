import Foundation

enum MockResponses {
    static let playlists = """
    [
      { "id": "1", "name": "Chill Vibes", "description": "Lo-fi beats to relax" },
      { "id": "2", "name": "Workout Hits", "description": "High energy tracks" },
      { "id": "3", "name": "Late Night Drive", "description": "Smooth sounds for the road" }
    ]
    """

    static let createPlaylist = """
    { "id": "4", "name": "My Playlist", "description": "A custom playlist" }
    """

    static let updatePlaylist = """
    { "id": "4", "name": "Updated Name", "description": "Updated description" }
    """

    static let deletePlaylist = """
    { "id": "4" }
    """
}
