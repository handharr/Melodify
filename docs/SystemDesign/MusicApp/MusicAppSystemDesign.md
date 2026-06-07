# MusicApp — System Design

## 1. Requirements

### Functional
- Search tracks by keyword via iTunes Search API; debounced, paginated (offset + limit)
- View track detail: artwork, artist, album, genre, duration, 30-second preview URL
- Home screen: featured tracks (genre-filtered) + user playlists fetched in parallel
- Browse playlist detail: playlist metadata + resolved track list
- Create a new playlist (name, description); update name/description of an existing playlist

### Non-Functional
- Track search results and detail are cached in **UserDefaults**; `FetchPolicy` on the `Request` controls whether the cached or network path is taken — set by the ViewModel, read only by the Repository
- Playlists are always fetched from the network — `PlaylistRepository` is remote-only with no local cache
- `FetchHomeSectionsUseCase` fetches N genre sections in parallel via `withThrowingTaskGroup`; `FetchHomeDataUseCase` fetches featured tracks + playlists concurrently via `async let`
- `PlaylistDetailUseCase` resolves each `trackId` to a full `Track` in parallel via `withThrowingTaskGroup`
- All ViewModel state mutations on `@MainActor` — no `DispatchQueue.main.async`
- `defer { isLoading = false }` guarantees cleanup on any exit path (success or throw)
- `SearchSessionService` owns query + page state; `begin(query:genre:)` resets to page 1, `advance()` increments for next page

---

## 2. API Design

### iTunes Search API (read-only, no auth)

| Action | Method | Endpoint |
|---|---|---|
| Search tracks | GET | `https://itunes.apple.com/search` |
| Track detail | GET | `https://itunes.apple.com/lookup` |

**Search query parameters**

| Param | Type | Example |
|---|---|---|
| `term` | String | `"Taylor Swift"` |
| `media` | String | `"music"` |
| `limit` | Int | `20` |
| `offset` | Int | `0` |

**Lookup query parameters**

| Param | Type | Example |
|---|---|---|
| `id` | Int | `1234567890` |

**Search response shape** (iTunes wraps results in an envelope)

```json
{
  "results": [
    {
      "trackId": 123,
      "trackName": "Anti-Hero",
      "artistName": "Taylor Swift",
      "collectionName": "Midnights",
      "artworkUrl100": "https://...",
      "previewUrl": "https://...",
      "primaryGenreName": "Pop",
      "trackTimeMillis": 200690
    }
  ]
}
```

### Playlist API (MockAPI.io, CRUD)

Base URL: `https://6a09e642e7e3f433d483900b.mockapi.io/api/v1/playlist`

| Action | Method | Endpoint | Body |
|---|---|---|---|
| Fetch all playlists | GET | `/playlist` | — |
| Fetch single playlist | GET | `/playlist/{id}` | — |
| Create playlist | POST | `/playlist` | `{ name, description, track_ids }` |
| Update playlist | PUT | `/playlist/{id}` | `{ name, description }` |

**Playlist response shape**

```json
{
  "id": 1,
  "name": "Morning Vibes",
  "description": "Chill tracks to start the day",
  "track_ids": [123, 456]
}
```

---

## 3. Data Model Design

### Domain Models (pure Swift structs, no external imports)

```swift
struct Track {
    let id: Int
    let title: String
    let artist: String
    let album: String
    let artworkURL: URL?
    let previewURL: URL?
    let genre: String
    let durationMs: Int
}

struct Playlist {
    let id: Int
    let name: String
    let description: String
    let trackIds: [Int]
}

struct PlaylistDetail {
    let playlist: Playlist
    let tracks: [Track]
}

struct HomeData {
    let featuredTracks: [Track]
    let playlists: [Playlist]
}

struct HomeSection {
    let genre: String
    let tracks: [Track]
}
```

### DTOs (Codable, mirror API shape exactly)

```swift
// iTunes API response item
struct TrackDTO: Codable {
    let trackId: Int?
    let trackName: String?
    let artistName: String?
    let collectionName: String?
    let artworkUrl100: String?
    let previewUrl: String?
    let primaryGenreName: String?
    let trackTimeMillis: Int?
}

// MockAPI.io playlist item
struct PlaylistDTO: Codable {
    let id: Int
    let name: String
    let description: String
    let trackIds: [Int]      // CodingKey: "track_ids"
}
```

### Mapper (the only type that knows both DTO and Domain)

```
TrackMapper.toDomain(_ dto: TrackDTO) -> Track?   // returns nil if trackId or trackName is missing
PlaylistMapper.toDomain(_ dto: PlaylistDTO) -> Playlist
```

---

## 4. High-Level Design

```
┌─────────────────────────────────────────────────────────────────┐
│  Presentation (UIKit + Combine)                                 │
│  TrackListViewController / TrackListViewModel                   │
│  TrackDetailViewController / TrackDetailViewModel               │
│  HomeViewController / HomeViewModel                             │
│  PlaylistDetailViewController / PlaylistDetailViewModel         │
└───────────────────────────┬─────────────────────────────────────┘
                            │ calls UseCases via protocol
┌───────────────────────────▼─────────────────────────────────────┐
│  Domain                                                         │
│  UseCases: SearchTracksUseCase, GetTrackDetailUseCase,          │
│            FetchHomeDataUseCase, FetchHomeSectionsUseCase,      │
│            PlaylistDetailUseCase, CreatePlaylistUseCase,        │
│            UpdatePlaylistUseCase                                │
│  Services: SearchSessionService (stateful: query + page state)  │
│  Protocols: TrackRepositoryProtocol, PlaylistRepositoryProtocol │
│             ImageRepositoryProtocol                             │
└───────────────────────────┬─────────────────────────────────────┘
                            │ implements protocols
┌───────────────────────────▼─────────────────────────────────────┐
│  Data                                                           │
│  TrackRepository — coordinates remote + local; applies FetchPolicy  │
│  PlaylistRepository — remote-only; no LocalDataSource, no policy    │
│  ImageRepository — image fetch + prefetch                           │
│  TrackRemoteDataSource → iTunes API (via CoreKit.APIClient)         │
│  TrackLocalDataSource  → UserDefaults-backed persistent cache       │
│  PlaylistRemoteDataSource → MockAPI.io (via CoreKit.APIClient)      │
│  TrackMapper, PlaylistMapper                                        │
└───────────────────────────┬─────────────────────────────────────┘
                            │ imports
┌───────────────────────────▼─────────────────────────────────────┐
│  CoreKit (shared SPM package)                                   │
│  APIClient, LocalDataSourceProtocol, ImageDataSourceProtocol    │
│  ImagePrefetcherProtocol, AnalyticsGatewayProtocol              │
└─────────────────────────────────────────────────────────────────┘
```

**Navigation (Coordinator pattern)**

```
MusicCoordinator
  └── UITabBarController
        ├── SearchCoordinator  → TrackListViewController → TrackDetailViewController
        └── HomeCoordinator    → HomeViewController → PlaylistDetailViewController
```

`MusicCoordinator` is the composition root — it builds the full dependency graph and injects into ViewModels via `init`.

---

## 5. Data Flow

### Search flow

```
User types in search bar
  → TrackListViewModel.search(term:)
      → SearchSessionService.begin(query: term, genre: nil)   // resets to page 1
          → returns SearchSession { request: SearchTracksRequest(query: .init(term:, page: 1, limit: 20), policy: .fresh) }
      → isLoading = true
      → SearchTracksUseCase.execute(request: session.request)
          → guard !term.trimmingCharacters(in: .whitespaces).isEmpty else return []
          → TrackRepository.searchTracks(request:)
              → FetchPolicy check (policy lives on Request, read only here — never passed further down):
                  policy.force && !policy.allowStale  → .fresh  → TrackRemoteDataSource → GET /search?term=...
                  !policy.force &&  policy.allowStale → .cached → UserDefaults lookup; if hit return, else remote
                  !policy.force && !policy.allowStale → .strict → UserDefaults lookup; throws APIError.notFound on miss
              → TrackMapper.toDomain(dto) → Track? (nil dropped — invalid data never crashes)
          → returns [Track]
      → ViewModel maps [Track] → [TrackUIModel]
      → @Published tracks updated → UICollectionView reloads
      → defer: isLoading = false

Next page (pagination):
  → SearchSessionService.advance()   // increments page, policy: .cached
  → SearchTracksUseCase.execute(request: session.request) — same flow
```

### Home featured + playlists flow (`async let`)

```
HomeViewController.viewDidLoad()
  → HomeViewModel.load()
      → isLoading = true
      → FetchHomeDataUseCase.execute(request:)
          // Two concurrent fetches — neither blocks the other
          → async let tracks   = TrackRepository.searchTracks(SearchTracksRequest(query: request.query.trackQuery))
          → async let playlists = PlaylistRepository.fetchPlaylists()   // always remote, no FetchPolicy
          → HomeData(featuredTracks: try await tracks, playlists: try await playlists)
      → ViewModel maps HomeData → UIModels
      → @Published state updated → View renders
      → defer: isLoading = false
```

### Home genre sections flow (`withThrowingTaskGroup`)

```
HomeViewController (genre sections mode)
  → HomeViewModel.loadSections(genres: ["Pop", "Rock", "Hip-Hop"])
      → isLoading = true
      → FetchHomeSectionsUseCase.execute(request: FetchHomeSectionsRequest(query: .init(genreQueries: [...])))
          // N concurrent fetches — one task per genre
          → withThrowingTaskGroup(of: HomeSection.self) { group in
                for (genre, query) in request.query.genreQueries:
                    group.addTask {
                        let tracks = try await TrackRepository.searchTracks(SearchTracksRequest(query: query))
                        return HomeSection(genre: genre, tracks: tracks)
                    }
                // collect results, re-sort to original genre order
                return sections.sorted { ... }
            }
      → ViewModel maps [HomeSection] → UIModels
      → defer: isLoading = false
```

### Playlist detail flow (`withThrowingTaskGroup`)

```
PlaylistDetailViewController.viewDidLoad()
  → PlaylistDetailViewModel.load(playlistId:)
      → isLoading = true
      → PlaylistDetailUseCase.execute(request: PlaylistDetailRequest(path: .init(playlistId:)))
          → PlaylistRepository.fetchPlaylist(id:) → Playlist   // remote, no cache
          // Resolve each trackId to a full Track in parallel
          → withThrowingTaskGroup(of: Track.self) { group in
                for trackId in playlist.trackIds:
                    group.addTask {
                        try await TrackRepository.getTrackDetail(GetTrackDetailRequest(path: .init(id: trackId)))
                    }
                return [Track] (unordered — ordering preserved by trackIds array at ViewModel level)
            }
          → PlaylistDetail(playlist:, tracks:)
      → ViewModel maps PlaylistDetail → UIModel
      → defer: isLoading = false
```

### Create playlist flow (mutation)

```
User taps "New Playlist", enters name + description
  → HomeViewModel.createPlaylist(name:, description:)
      → isLoading = true
      → CreatePlaylistUseCase.execute(request: CreatePlaylistRequest(name:, description:))
          → guard !name.isEmpty else throw PlaylistError.emptyName
          → PlaylistRepository.createPlaylist(request:)
              → PlaylistRemoteDataSource.createPlaylist → POST /playlist { name, description, track_ids: [] }
              → PlaylistDTO → PlaylistMapper.toDomain → Playlist
      → ViewModel appends new Playlist to playlists array
      → @Published state → View reloads
      → defer: isLoading = false
```
