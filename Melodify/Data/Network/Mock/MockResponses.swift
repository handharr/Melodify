import Foundation

enum MockResponses {
    static let playlists = """
    [
      { "id": 1, "name": "Chill Vibes", "description": "Lo-fi beats to relax", "track_ids": [123, 456] },
      { "id": 2, "name": "Workout Hits", "description": "High energy tracks", "track_ids": [] },
      { "id": 3, "name": "Late Night Drive", "description": "Smooth sounds for the road", "track_ids": [789] }
    ]
    """

    static let playlist = """
    { "id": 1, "name": "Chill Vibes", "description": "Lo-fi beats to relax", "track_ids": [123, 456] }
    """

    static let createPlaylist = """
    { "id": 4, "name": "My Playlist", "description": "A custom playlist", "track_ids": [] }
    """

    static let updatePlaylist = """
    { "id": 4, "name": "Updated Name", "description": "Updated description", "track_ids": [] }
    """

    static let deletePlaylist = """
    { "id": 4, "name": "", "description": "", "track_ids": [] }
    """
}
