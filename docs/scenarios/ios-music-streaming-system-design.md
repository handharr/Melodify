# iOS Music Streaming App — System Design

**Source:** Senior iOS Engineer Mock Interview (Andrey Tech with Liam Ronan)  
**Progress:** ✅ Requirements · ✅ API & Data Model · ✅ High-Level Architecture · ✅ Streaming & Playback · ✅ Feedback

> **Scenario extension of** [`docs/ios-app-system-design-philosophy.md`](../ios-app-system-design-philosophy.md)  
> Read the delta below first — it describes what this scenario adds or changes on top of the generic architecture.

---

## Delta — What This Scenario Adds

### Same as generic architecture

All patterns not listed above are unchanged — see [ios-app-system-design-philosophy.md](../ios-app-system-design-philosophy.md).

### What this scenario adds
| Concept | Generic | Music Streaming |
|---|---|---|
| Local storage | LocalDataSource (cache) | Two tiers: metadata cache (GRDB) + file storage (LRU disk cache) |
| File storage | Not in generic | `MediaFileDataSource` — binary audio files on disk, LRU 5 GB |
| Offline saves | Not in generic | `DownloadLocalDataSource` — maps `itemId → localFilePath` |
| Domain Services | Generic (SessionService example) | `PlayerService` (app-scoped, owns queue + playback state) · `StreamRefreshService` (manifest expiry logic) |
| Audio playback | Not in generic | `AudioPlayerProtocol` (Domain) · `AudioPlayerDataSource: AudioPlayerProtocol` (Data) — wraps AVPlayer + AVAudioSession; same pattern as any other DataSource wrapping an external framework |
| Streaming | Not in generic | HLS via `AVPlayer` — adaptive bitrate, chunk-based, short-lived signed URLs |
| Pagination | Not in generic | Cursor-based (not offset) — library syncs live across devices |
| Playback asset resolution | Not in generic | logic inside `PlayerService`: offline file → HLS manifest → `AudioPlayerDataSource` (`AudioPlayerProtocol`) → AVPlayer |
| UI framework | SwiftUI default for new apps; UIKit when scroll lifecycle, AVPlayer, or custom transitions needed; hybrid valid screen-by-screen | UIKit throughout — AVPlayer integration, scroll lifecycle for library list, custom transitions for playback screen |

### Key decisions unique to this scenario
- **`PlayerService` must be app-scoped** — if owned by a ViewController it deallocates when the screen pops and music stops
- **`AudioPlayerDataSource` lives in Data, not Domain** — it imports AVFoundation; `AudioPlayerProtocol` stays in Domain so `PlayerService` depends on nothing external
- **Two separate `MediaFileDataSource` instances** — streaming LRU cache and explicit offline saves must never share storage (cache pressure must not evict user-saved tracks)
- **`stream-info` is a separate endpoint** — manifest URL is short-lived; decoupled from item metadata so it can be refreshed without invalidating the rest of the model
- **Queue is client-owned** — built via `PlayableItemRepository` (.strict policy, local-only) by `PlayerService`; no server round-trip on every playback action

---

## Screens in Scope

| Screen | Description |
|---|---|
| Your Library | Scrollable list of collections (playlists, albums, podcasts), sortable |
| Playlist / Album | Cover art + metadata + track list, play from start or any track |
| Playback | Album art, seek bar, shuffle / prev / play / next controls |

---

## Requirements

### Functional
- User can view their library sorted by recent / last listened
- User can view details of a collection
- User can play a collection from start or any index
- User can control playback including seek

### Non-Functional
- **Offline support** — via explicit "save locally" button
- **Low network support** — adaptive bitrate streaming
- **Scale** — 100M DAU

---

## API Design

### Key Decisions
- **REST + JSON**, authentication assumed
- **Cursor-based pagination** over offset — prevents missing/duplicate items when library order changes mid-scroll (e.g. desktop sync)
- **Sort as API param**, not client-side only — client doesn't have full library context at large scale

> **Why REST over GraphQL?**
> REST is simpler to cache at the CDN/network layer — each endpoint maps to a predictable URL. GraphQL POST requests are harder to cache and add client complexity (query language, schema). For a mobile app with well-defined screens and known data shapes, REST is sufficient. GraphQL pays off when many different clients need different field subsets — not the case here.

> **Why JSON over Protobuf/MessagePack?**
> JSON is human-readable (easier to debug in Charles/Proxyman), natively supported by `Codable`, and fast enough for library-sized payloads. Protobuf wins on bandwidth for very high frequency or very large payloads — not a bottleneck for this design.

### Endpoints

```
GET /me/library?sort={recent|date_added}&cursor={}&limit={}
→ {
    libraryItems: [LibraryItem],
    nextCursor: Cursor?
  }

GET /collections/{id}?cursor={}
→ {
    collectionSummary: CollectionSummary,
    collectionDetail: CollectionDetail,
    items: [PlayableItem],
    nextCursor: Cursor?     // omitted from whiteboard but required — playlists can have 1000s of tracks
  }

GET /item/{id}
→ { item: PlayableItem }

GET /item/{id}/stream-info
→ {
    type: "HLS",
    manifestUrl: String,
    expiresAt: Date
  }
```

> `stream-info` is a **separate endpoint** — not bundled with item detail. Keeps the manifest URL short-lived without invalidating the rest of the model.

---

## Data Model

```swift
struct LibraryItem {
    id: UUID
    collectionSummary: CollectionSummary
    updatedAt: Date
    lastListenAt: Date          // used for "sorted by recent"
}

struct CollectionSummary {
    id: UUID
    title: String
    itemCount: Int
    type: playlist | album | podcast
    artworkUrl: URL
}

struct CollectionDetail {
    albumNotes: String?         // intentionally sparse — only extra metadata for detail screen
    description: String?
}

// Polymorphic — handled as enum in Swift
enum PlayableItem {
    case track(Track)
    case episode(Episode)
}
// Why enum over protocol/class inheritance?
// Enum gives exhaustive switch — the compiler forces you to handle every case.
// Protocol polymorphism lets new types slip in silently; inheritance adds coupling.
// For a closed set of types (track, episode) enum is the right tool.

struct Track {
    title: String
    artist: String
    // always starts from beginning — no resume logic needed
}

struct Episode {
    title: String
    artist: String
    resumeTimestamp: TimeInterval   // required — episodes resume from last position
}

struct PlayableAsset {
    itemId: UUID
    streamInfo: StreamInfo
}

struct StreamInfo {
    manifestUrl: URL
    expiresAt: Date             // client must refresh manifest before expiry
}

struct PlaybackState {
    state: idle | playing | paused | seeking
    asset: PlayableAsset
    queue: Queue                // Queue — structure not defined in video; client-owned (see below)
}
```

### Why Separate `PlayableItem` vs `PlayableAsset`?
- `PlayableItem` is the **library/list representation** (title, artist, artwork)
- `PlayableAsset` is the **streaming representation** (stream URL, expiry)
- Separation prevents exposing short-lived signed URLs to list views that don't need them

### Queue Ownership — Client-Side
Queue is **not a server concept** — the client builds and manages it locally using items already fetched.  
`PlayerService` acts as the controller: when the user taps "play from index N", `PlayerService` calls `PlayableItemRepository` (`.strict` policy — local only, no network) to construct the queue. No extra network call needed.

> **Interview note:** This is an important architectural decision — pushing queue state to the server would add latency on every playback action and complicate state sync across devices. Client ownership is simpler and sufficient for the stated requirements.

---

## Architecture

Pattern: **MVVM + Clean Architecture** — Presentation → Domain ← Data. Same rule as Melodify.

> **Why UIKit over SwiftUI?**
> UIKit gives fine-grained control over scroll performance, custom transitions, and `AVPlayerViewController` integration — all critical for a music app. SwiftUI's `List` and animation model can't yet match UIKit for complex interactive layouts. SwiftUI is the right choice for new simple screens; UIKit is still preferred when you need full control over performance and native media playback.

> **Why GRDB over Core Data?**
> Core Data has a steep learning curve, complex concurrency model (`NSManagedObjectContext`), and generates verbose boilerplate. GRDB is plain SQLite with a Swift-first API — you write SQL you understand, get Combine publishers out of the box, and have no magic behind the scenes. Core Data wins if you need CloudKit sync or already have an existing Core Data stack. For greenfield, GRDB is simpler and faster to iterate on.

### Concept Translation (video terms → your terms)

| Video (Liam's style) | Your style |
|---|---|
| `LibraryRepo` | `LibraryRepository: LibraryRepositoryProtocol` |
| `CollectionRepo` | `CollectionRepository: CollectionRepositoryProtocol` |
| `PlayableItemRepo` | `PlayableItemRepository: PlayableItemRepositoryProtocol` |
| `APIClient` | `LibraryRemoteDataSource`, `CollectionRemoteDataSource`, `PlayableItemRemoteDataSource`, `MediaRemoteDataSource` |
| `LocalDB / GRDB` | `LibraryLocalDataSource`, `CollectionLocalDataSource`, `PlayableItemLocalDataSource`, `DownloadLocalDataSource` |
| `LibraryStore` / `CollectionStore` / `PlayableItemStore` | **gone** — this is just what `LibraryLocalDataSource`, `CollectionLocalDataSource`, etc. return |
| `PlaybackAssetResolver` | logic inside `PlayerService` (Domain Service) |
| `PlayerService` | `PlayerService` — Domain Service, app-scoped |
| *(not in video)* | `StreamRefreshService` — Domain Service, expiry check logic |
| `DownloadStore` | `DownloadLocalDataSource` — maps `itemId → localFilePath` |
| `DownloadService` | `DownloadTrackUseCase` + `MediaRemoteDataSource` + `MediaFileDataSource` |

### Layer Breakdown

```
Presentation
  LibraryViewController       → LibraryViewModel       → FetchLibraryUseCase
  CollectionDetailViewController → CollectionDetailViewModel → FetchCollectionUseCase
                                                           → FetchPlayableItemsUseCase
  PlayerViewController        → PlayerViewModel         → PlayerService (app-scoped)
                                                        → ResolvePlaybackAssetUseCase

  UIModels: LibraryUIModel, CollectionUIModel, PlaybackUIModel
    └─ All ViewModels map Domain model → UIModel; View never receives Domain types directly.

Domain
  Protocols:  LibraryRepositoryProtocol
              CollectionRepositoryProtocol
              PlayableItemRepositoryProtocol
              DownloadRepositoryProtocol

  UseCases:   FetchLibraryUseCase          execute(policy:param:) → [LibraryItem]
              FetchCollectionUseCase        execute(policy:param:) → CollectionDetail
              FetchPlayableItemsUseCase     execute(policy:param:) → [PlayableItem]
              FetchStreamInfoUseCase        execute(policy:param:) → StreamInfo
              DownloadTrackUseCase          execute(param:)

  // Stateful / reusable logic — not tied to a single user action
  DomainServices:
              PlayerService               owns PlaybackState, queue, shuffle/repeat logic
                                          app-scoped singleton — survives screen transitions
                                          calls AudioPlayerProtocol for actual audio playback
              StreamRefreshService        pure logic — given StreamInfo.expiresAt,
                                          decides when to trigger FetchStreamInfoUseCase
                                          Note: Domain Service (not a UseCase) — it is stateful
                                          (holds expiry thresholds, manages timing) and
                                          long-lived; fails both UseCase criteria (stateless,
                                          triggered per user action)

  Protocols:  AudioPlayerProtocol         play(url:), pause(), stop(), seek(to:), updateManifest(_:)
                                          defined in Domain — PlayerService depends on nothing external

  Models:     LibraryItem, CollectionSummary, CollectionDetail
              PlayableItem (enum: track / episode), Track, Episode
              PlayableAsset, StreamInfo, PlaybackState

Data
  AudioPlayerDataSource: AudioPlayerProtocol
    └─ wraps AVPlayer + AVAudioSession — imports AVFoundation
    └─ exposes play(url:), pause(), stop(), seek(to:), updateManifest(_:)
    └─ concrete implementation of Domain protocol — same rule as LibraryRepository implements LibraryRepositoryProtocol

  LibraryRepository
    ├─ remoteDataSource: LibraryRemoteDataSource   (→ APIClient → API Gateway)
    └─ localDataSource:  LibraryLocalDataSource    (→ GRDB, SSOT)

  CollectionRepository
    ├─ remoteDataSource: CollectionRemoteDataSource
    └─ localDataSource:  CollectionLocalDataSource

  PlayableItemRepository
    ├─ remoteDataSource: PlayableItemRemoteDataSource
    └─ localDataSource:  PlayableItemLocalDataSource

  DownloadRepository
    ├─ remoteDataSource: MediaRemoteDataSource     (→ HLS CDN)
    ├─ localDataSource:  DownloadLocalDataSource   (itemId → localFilePath metadata)
    └─ fileDataSource:   MediaFileDataSource       (actual binary on disk, LRU 5 GB)

  Mappers (only type that knows both DTO and Domain model):
    LibraryItemMapper.toDomain(_:)
    CollectionMapper.toDomain(_:)
    PlayableItemMapper.toDomain(_:)    ← handles Track vs Episode polymorphism
    StreamInfoMapper.toDomain(_:)

Infrastructure
  None

External
  AVFoundation
  GRDB
  URLSession

Application
  AppCoordinator (composition root — builds full dependency graph, registers app-scoped services)
  AppDelegate (entry point — wires window, registers PlayerService at app scope)
  Manual init injection — no DI framework; Coordinators compose all dependencies via init
```

### FetchPolicy applies here too
Same `.fresh / .cached / .strict` you use in Melodify — `LibraryRepository` checks policy before deciding to hit remote or return from local. No new concept needed.

### Why `PlayableItemRepository` is separate from `CollectionRepository`
Same reason you'd split `TrackRepository` from `PlaylistRepository` in Melodify:
1. **Deep link / direct access** — a track URL can open without collection context
2. **Granular cache invalidation** — refresh one episode's `resumeTimestamp` without busting the whole collection cache

### PlayerService Scope
`PlayerService` is a Domain Service — must live at **app-level** (registered in your DI container at startup), not inside any ViewController.

> If `PlayerService` is owned by `PlayerViewModel`, it deallocates when the Player screen pops — music stops. Same rule as any shared service in your company codebase: scope it to the lifetime you need, not the screen that first uses it.

### Storage
| DataSource | Purpose | Eviction |
|---|---|---|
| `LibraryLocalDataSource` / `CollectionLocalDataSource` | Metadata (GRDB) | TTL / manual |
| `MediaFileDataSource` (explicit download) | User-saved offline tracks | Never (user-controlled) |
| `MediaFileDataSource` (LRU cache) | Recently streamed chunks | LRU, max 5 GB |

Two separate `MediaFileDataSource` instances — offline saves can never be evicted by streaming cache pressure.

> **Why LRU over FIFO or LFU eviction?**
> FIFO (First In, First Out) evicts the oldest item regardless of how recently it was used — you might evict an album the user plays every day. LFU (Least Frequently Used) favours popular items but is expensive to track and punishes newly added content. LRU evicts what hasn't been touched recently — a good proxy for "user probably doesn't need this anymore." Simple to implement, good real-world performance for media caches.

> **Why 5 GB cap?**
> Roughly 40–60 full albums at 128kbps. Enough to give meaningful background caching without consuming a significant share of a typical iPhone's storage (128–256 GB). Configurable — expose it as a user setting ("Storage limit") to let users tune it.

### Testing
- Unit: mock the DataSource below the Repository, assert on what the Repository returns
- Integration: real GRDB + mock RemoteDataSource
- UI: core flows only — keep minimal to avoid flakiness
- Manual: required for audio playback — simulator doesn't fully replicate `AVAudioSession`

## Data Flow

### Data Flow — Library Screen

Pattern A — two awaits in the ViewModel. `async/await` returns once; a single `execute()` cannot update state twice.

```
LibraryViewModel.load()
    → isLoading = true

    // Phase 1 — cache (instant)
    if let cached = try? await FetchLibraryUseCase.execute(policy: .strict, param:)
        → LibraryRepository checks LibraryLocalDataSource only — throws on miss
        → ViewModel maps [LibraryItem] → UIModel
        → @Published state updated → UI renders immediately from cache

    // Phase 2 — network (background)
    let fresh = try await FetchLibraryUseCase.execute(policy: .fresh, param:)
        → LibraryRepository fetches LibraryRemoteDataSource → DTOs → LibraryItemMapper → [LibraryItem]
        → LibraryLocalDataSource.save(dtos)
        → ViewModel maps [LibraryItem] → UIModel
        → @Published state updated → UI refreshes with latest

    → defer: isLoading = false
```

### Data Flow — Collection Detail Screen

Two use cases run concurrently — collection metadata and track list come from the same API endpoint but cache independently.

```
CollectionDetailViewModel.load(collectionId)
    → isLoading = true

    // Phase 1 — cache (instant)
    async let cachedCollection = FetchCollectionUseCase.execute(policy: .strict, param:)
    async let cachedItems     = FetchPlayableItemsUseCase.execute(policy: .strict, param: .init(collectionId:, cursor: nil))
    if let (collection, items) = try? await (cachedCollection, cachedItems)
        → UI renders immediately from cache

    // Phase 2 — network (background)
    async let freshCollection = FetchCollectionUseCase.execute(policy: .fresh, param:)
    async let freshItems      = FetchPlayableItemsUseCase.execute(policy: .fresh, param: .init(collectionId:, cursor: nil))
    let (collection, page) = try await (freshCollection, freshItems)
        → CollectionRepository → CollectionRemoteDataSource → GET /collections/{id}
        → CollectionMapper → CollectionSummary + CollectionDetail → CollectionLocalDataSource.save()
        → PlayableItemMapper → [PlayableItem] → PlayableItemLocalDataSource.save()
        → nextCursor = page.nextCursor
        → @Published state updated → UI refreshes

    → defer: isLoading = false
```

> **Why `async let` here?** Collection metadata and items are independent — no ordering dependency. Running concurrently saves one full round-trip latency.

### Data Flow — Pagination (Load More)

```
LibraryViewModel.loadNextPage()
    guard let cursor = nextCursor else { return }   // nil → no more pages; guard prevents redundant calls

    isPaginating = true
    let page = try await FetchLibraryUseCase.execute(policy: .fresh, param: .init(cursor: cursor))
        → LibraryRepository → LibraryRemoteDataSource (cursor: cursor)
        → DTOs → LibraryItemMapper → [LibraryItem]
        → LibraryLocalDataSource.append(items)      // append — do not replace existing rows
        → [LibraryItem] returned

    → @Published items += page.items                // append to existing list, not replace
    → nextCursor = page.nextCursor                  // nil if last page
    → defer: isPaginating = false
```

> **Why append to LocalDataSource, not replace?** The user may have scrolled to page 3 — overwriting GRDB would wipe rows 1–2 from the cache on next cold launch. Append preserves the full list locally.

### Data Flow — Download Track (Save for Offline)

```
CollectionDetailViewModel.saveForOffline(itemId)
    → DownloadTrackUseCase.execute(param: .init(itemId:))
        1. PlayableItemRepository (policy: .strict) → PlayableItemLocalDataSource
               confirms item exists locally before attempting download
        2. MediaRemoteDataSource.downloadFile(for: itemId)
               → full audio file from CDN (not HLS chunks — complete file download)
        3. MediaFileDataSource (explicit offline store).save(data, for: itemId)
               → written to separate store — never subject to LRU eviction
        4. DownloadLocalDataSource.save(itemId → localFilePath)
               → records the itemId → file:// path mapping
    → @Published downloadState[itemId] = .saved → UI shows "Saved ✓"
```

> **Why confirm item exists locally first (step 1)?** Prevents downloading a track whose metadata was never cached — the UI model would have no title, artwork, or artist to show in the offline library.

> **Why a separate `MediaFileDataSource` instance, not the LRU cache?** The LRU cache evicts under storage pressure. An explicitly saved track must survive indefinitely until the user deletes it. Two separate stores guarantee cache pressure can never remove an offline save.

### Data Flow — Playback (Initial Play)
```
PlayerViewModel.play(item, at: index)
  → PlayerService [Domain Service — app-scoped]

      // Step 1 — build queue from cached metadata only (no CDN URL yet)
      PlayableItemRepository (policy: .strict) → PlayableItemLocalDataSource
          returns [PlayableItem] { id, title, artist, resumeTimestamp }
          // metadata only — no manifest URL, no audio data
          // .strict because items are already cached from the Collection Detail screen load

      // Step 2 — resolve asset for the item about to play (lazy, per-item)
      DownloadRepository: is this item downloaded offline?
          ├─ yes → file:// URL → AudioPlayerDataSource (AudioPlayerProtocol)
          │         // skip CDN entirely
          └─ no  → FetchStreamInfoUseCase → GET /item/{id}/stream-info
                     → manifestUrl (HLS .m3u8) + expiresAt
                     // fetched NOW, not at queue-build time —
                     // manifest is short-lived (~1hr); fetching upfront for all
                     // queue items would expire before user reaches them
                   → AudioPlayerDataSource (AudioPlayerProtocol) → AVPlayer(url: manifestUrl)
                   → AVPlayer streams chunks from CDN adaptively

      // Step 3 — hand expiry management to StreamRefreshService
      StreamRefreshService monitors expiresAt in background
          → near expiry → FetchStreamInfoUseCase → fresh manifestUrl
          → AudioPlayerProtocol.updateManifest(_:) — buffered chunks play uninterrupted
```

> **Why `PlayableItemRepository` never returns a CDN URL:** `PlayableItem` is metadata — title, artist, artwork. `PlayableAsset` is the streaming representation — manifest URL, expiry. They are intentionally separate types. List views and queue building only need metadata. The CDN URL is fetched lazily at the moment of playback so it never expires before use.

### Data Flow — Seek
```
PlayerViewController seek bar drag ends
  → PlayerViewModel.seek(to: fraction)
    → PlayerService.seek(to: TimeInterval)
        1. guard state.status == .playing || .paused else { return }
        2. wasPlaying = (state.status == .playing)
        3. state = state.with(status: .seeking)     // transient — UI shows seeking indicator
        4. AudioPlayerProtocol.seek(to: time) { [weak self] in
               self?.state = state.with(status: wasPlaying ? .playing : .paused)  // always restore
           }
        // AVPlayer owns everything below — chunk lookup, CDN fetch, buffer management
```

> **Why `.seeking` must be transient:** always restore state in the completion handler — `.playing` or `.paused`, never leave it stuck at `.seeking`.

### Data Flow — Chunk Lifecycle
```
AVPlayer needs chunk_N for continuous playback

  ├─ LRU cache hit (MediaFileDataSource, Tier 2)
  │    → serve chunk from disk → no network round-trip
  │
  └─ LRU cache miss
       → AVPlayer fetches chunk_N from CDN
       → chunk decoded → written to Tier 1 memory buffer (AVPlayer owns — you never touch this)
       → MediaFileDataSource.write(chunk_N) → LRU disk cache (Tier 2)
           cache size > 5 GB? → evict least-recently-used chunk
       → chunk plays out → memory buffer advances to chunk_N+1

StreamRefreshService runs in parallel:
  → checks StreamInfo.expiresAt - refreshThreshold (e.g. 60s)
  → if near expiry → FetchStreamInfoUseCase (background)
       → new manifestUrl swapped via AudioPlayerProtocol.updateManifest(_:)
       → chunks already in Tier 1 buffer play uninterrupted
```

> **Why cache chunks to disk at all (Tier 2)?** If the user replays the same track, or seeks backward, AVPlayer would re-fetch from CDN without the LRU cache. Tier 2 turns replays into disk reads — no network, no stall.

### Data Flow — Queue Advance (Track Ends)
```
AVPlayer fires .AVPlayerItemDidPlayToEndTime
  → AudioPlayerDataSource receives notification → AudioPlayerProtocol.onTrackEnded()
    → PlayerService
        1. Episode only: save resumeTimestamp = 0 via UpdateEpisodeProgressUseCase
               (marks episode complete — next play starts from beginning)
        2. queue.advance() → next PlayableItem
        3. queue exhausted?
               └─ yes → state = state.with(status: .idle)
        4. queue has next item → resolve asset (same offline/stream decision as initial play):
               DownloadRepository: downloaded?
                 ├─ yes → file:// URL → AudioPlayerDataSource
                 └─ no  → FetchStreamInfoUseCase → MediaRemoteDataSource → HLS manifest
        5. AudioPlayerDataSource.play(url:) with next asset
```

> **Why Episode saves `resumeTimestamp = 0` on completion, not on pause?** On pause the timestamp is the current position. On natural completion it should reset to zero — next play starts from the beginning. Track has no `resumeTimestamp` at all; the compiler enforces this via the enum.

---

## Technical Deep Dives

### 1. Pagination — offset vs cursor

#### Offset-based pagination

```
GET /me/library?page=2&limit=20
→ server: SELECT * FROM library OFFSET 20 LIMIT 20
```

Simple. But breaks when items are inserted mid-scroll:

```
Page 1 fetch:   [A, B, C, D, E, F, G, H, I, J]
                              ↑
                    New item "X" inserted here (desktop sync)

Page 2 fetch:   [F, G, H, I, J, K, ...]   ← F already seen — duplicate
```

For a library that syncs across phone/desktop/web, items shift constantly. Offset pagination will skip or duplicate items.

---

#### Cursor-based pagination

```
GET /me/library?cursor=eyJpZCI6IkYifQ&limit=20
→ server: SELECT * FROM library WHERE id > :cursor LIMIT 20
```

The cursor is a **pointer to a specific item**, not a position number.

```
Page 1 fetch:   [A, B, C, D, E, F, G, H, I, J]  → nextCursor points to J
                              ↑
                    New item "X" inserted here

Page 2 fetch using cursor → J:   [K, L, M, ...]  ← starts after J, unaffected
```

No skips, no duplicates, regardless of insertions or deletions.

**Why the cursor is an opaque string (base64):**
Client never parses it — just stores and sends it back. Server decides what's inside (ID, timestamp, composite key). Server can change internal logic without breaking clients.

```swift
// Client code — treat cursor as a black box
var nextCursor: String? = nil

func loadNextPage() {
    guard let cursor = nextCursor else { return }
    fetch(cursor: cursor)
}

// On response
nextCursor = response.nextCursor  // store, never inspect
```

---

#### Why cursor is an opaque string, not a typed struct?

Exposing cursor internals (e.g. `{ id: "abc", timestamp: 123 }`) couples the client to server implementation. If the server changes its cursor strategy (e.g. switches from ID-based to composite key), every client breaks. An opaque base64 string hides that detail — the client just echoes it back. This is the same principle as treating an `ETag` as opaque in HTTP caching.

#### Cursor vs Offset — when to use each

| | Cursor | Offset |
|---|---|---|
| Live-synced data (library) | ✅ | ❌ skips/duplicates |
| Static / rarely changing data | Overkill | ✅ simpler |
| Server implementation | Harder | Easy |
| Client implementation | Easy (opaque string) | Easy |
| Jump to arbitrary page | ❌ | ✅ |

**In this design:**
- `/me/library` → **cursor** — syncs live across devices, order changes constantly
- `/collections/{id}` items → **cursor** — playlists can have thousands of tracks, same risk
- Search results → **offset** would be fine — results don't change mid-scroll

---

### 2. Streaming & Playback Flow

#### HLS Flow
```
PlayerService triggers playback
  → logic inside PlayerService checks DownloadRepository (DownloadRepositoryProtocol)
      ├─ downloaded? → file:// URL → AudioPlayerDataSource (AudioPlayerProtocol)
      └─ not downloaded? → FetchStreamInfoUseCase → DownloadRepository (DownloadRepositoryProtocol) → MediaRemoteDataSource → HLS CDN
                             → manifest (.m3u8)
                             → quality buckets → chunks (2–10s each)
                             → AVPlayer streams chunks adaptively
```

#### manifest `expiresAt` — Refresh During Playback
- `PlayerService` (via `AudioPlayerProtocol` → `AudioPlayerDataSource`) monitors chunk-boundary; `StreamRefreshService` checks `expiresAt` before the next chunk request
- If near expiry → background task fetches a fresh `stream-info` via `FetchStreamInfoUseCase` → `MediaRemoteDataSource`
- Refresh happens **without interrupting the active audio buffer** — chunks already buffered keep playing while the new manifest loads
- Owner: `PlayerService` (via `AudioPlayerProtocol` + `StreamRefreshService`), not the ViewModel

#### Offline Playback — Two Paths

| Scenario | Approach |
|---|---|
| Standard downloaded files | logic inside `PlayerService` returns `file://` URL directly to `AVPlayer` — no extra work |
| Protected / chunked format | Custom `AVAssetResourceLoadingDelegate` intercepts requests and serves local binary data |

Initial implementation uses the simple `file://` path. `DownloadLocalDataSource` holds the `itemId → localFilePath` mapping; logic inside `PlayerService` accesses it via `DownloadRepository`.

> **Why `file://` URL over `AVAssetResourceLoadingDelegate`?**
> `AVAssetResourceLoadingDelegate` lets you intercept every network request AVPlayer makes and serve data yourself — useful for DRM, encryption, or proprietary chunk formats. But it adds significant complexity (manage loading requests, handle cancellation, deal with byte-range requests). For standard downloaded audio files, a plain `file://` URL is sufficient and far simpler. Use `AVAssetResourceLoadingDelegate` only when the file format or protection requires it.

#### Background Audio
- App must declare `audio` background mode in project settings
- `AVAudioSession` category set to `.playback` — allows audio to continue when app backgrounds
- `PlayerService` must be **app-level singleton** (not owned by a ViewModel) so the audio thread stays alive across screen transitions and backgrounding

> **Interview note:** Background audio and `PlayerService` scope are the same problem — both require the service to outlive any single screen. Solve the scope problem once and both are solved.

---

### 3. What is HLS and why does it exist?

HLS (HTTP Live Streaming) solves one problem: **audio quality degrades or buffers on slow networks**.

The naive approach — serve one large audio file — falls apart because:
- You can't switch quality mid-way if the network drops
- The whole file must download before playback starts
- A leaked URL gives permanent access to the full track

HLS solves all three by splitting the audio into small chunks and letting the player pick quality dynamically.

---

### 4. How HLS works — step by step

```
1. Client requests stream-info from your API
   → receives a manifestUrl (an .m3u8 file)

2. Client fetches the manifest from the CDN
   → manifest lists available quality levels:

     #EXT-X-STREAM-INF:BANDWIDTH=128000   ← low quality
     https://cdn.example.com/low/index.m3u8

     #EXT-X-STREAM-INF:BANDWIDTH=320000   ← high quality
     https://cdn.example.com/high/index.m3u8

3. Client picks a quality and fetches its playlist
   → that playlist lists individual chunks:

     #EXTINF:6.0,
     https://cdn.example.com/high/chunk_001.aac

     #EXTINF:6.0,
     https://cdn.example.com/high/chunk_002.aac
     ...

4. Client downloads chunks one at a time, plays them in sequence
5. If bandwidth drops → switch to low quality playlist → next chunk is lower bitrate
   No restart. Seamless.
```

**Key insight:** the client never downloads the whole file. It only ever has a few seconds of buffer ahead of playback.

---

### 5. AVPlayer and HLS on iOS

You barely write any streaming code yourself — AVPlayer handles it all:

```swift
// This is literally all you need for HLS streaming
let url = URL(string: "https://cdn.example.com/manifest.m3u8")!
let player = AVPlayer(url: url)
player.play()
```

AVPlayer internally:
- Fetches and parses the manifest
- Monitors available bandwidth
- Switches quality levels automatically
- Buffers a few chunks ahead of playback
- Handles chunk download retries

Your job is to give it the right URL and configure `AVAudioSession`.

---

### 6. AVAudioSession — required for real playback

Without this, audio stops when the screen locks or the app backgrounds:

```swift
// Called inside AudioPlayerDataSource (Domain) — never in AppDelegate or ViewModel directly
try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
try AVAudioSession.sharedInstance().setActive(true)
```

Also requires `audio` background mode declared in `Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

---

### 7. File storage — three tiers

```
Tier 1: Memory buffer (AVPlayer owns this)
  → A few seconds of decoded audio ahead of the playhead
  → Freed when track changes
  → You never touch this

Tier 2: LRU disk cache (your DownloadTrackUseCase / MediaFileDataSource writes this)
  → Recently streamed chunk files on disk
  → Max size: 5 GB, evicts least-recently-used when full
  → Purpose: if user replays a track, skip the network entirely
  → You manage this

Tier 3: Explicit download (user taps "Save for offline")
  → Full track downloaded and stored permanently
  → Never evicted — only removed when user explicitly deletes
  → You manage this, separately from Tier 2
```

**Why keep Tier 2 and Tier 3 separate?**
If they shared storage, cache pressure (from streaming) could evict an explicitly saved offline track. Separate stores means that can never happen.

---

### 8. Offline playback — how AVPlayer reads local files

When a track is fully downloaded, skip the CDN entirely:

```swift
// Online path
let url = URL(string: "https://cdn.example.com/manifest.m3u8")!

// Offline path — just a local file URL
let url = URL(fileURLWithPath: "/var/mobile/.../track_123.m4a")

// AVPlayer doesn't care which one it is
let player = AVPlayer(url: url)
player.play()
```

Logic inside `PlayerService` decides which URL to hand to `AVPlayer` by calling through `DownloadRepository` (injected via `DownloadRepositoryProtocol`):
```
DownloadRepository.localFilePath(for: itemId)   // protocol call — Domain knows nothing about DownloadLocalDataSource
  ├─ found → file:// URL (offline)
  └─ nil   → FetchStreamInfoUseCase → DownloadRepository → MediaRemoteDataSource → HLS manifest URL (streaming)
```

---

### 9. Short-lived URLs — why and how

**Why URLs expire:**
A permanent CDN URL can be extracted from a packet sniffer and shared publicly. A signed URL with an expiry (e.g. 1 hour) is useless after it expires.

**How it works:**
```
Server signs the URL with a secret:
  https://cdn.example.com/track_123.m3u8?token=abc&expires=1716490800

CDN validates the token + expiry on every request.
After expiresAt → CDN returns 403.
```

**How the client handles it:**
```
Before fetching each new chunk:
  StreamRefreshService.needsRefresh(for: streamInfo)
    → checks: Date() > streamInfo.expiresAt - refreshThreshold (e.g. 60s)
    → if yes → background fetch new stream-info from API
    → swap manifest URL via AudioPlayerProtocol.updateManifest(_:) (→ AudioPlayerDataSource)
    → buffered chunks already playing are unaffected
```

The refresh is invisible to the user — chunks already in the buffer play out while the new manifest loads in the background.

---

### 10. LRU Cache — how it works

LRU = Least Recently Used. When the cache is full, it evicts the item that was accessed least recently.

```
Cache state (max 3 items for illustration):
  [chunk_A (oldest), chunk_B, chunk_C (newest)]

User plays a new track → chunk_D needs to be cached:
  → Cache is full → evict chunk_A (least recently used)
  → [chunk_B, chunk_C, chunk_D]

User replays chunk_B → it gets promoted to newest:
  → [chunk_C, chunk_D, chunk_B]
```

In practice (max 5 GB):
- Each chunk is ~50–200 KB
- 5 GB holds tens of thousands of chunks — roughly 40–60 full albums
- Eviction is by byte size, not item count

You implement this with an `NSCache` (auto-evicts under memory pressure) or a manual SQLite-backed LRU using GRDB.

---

### 11. Bad network handling — adaptive bitrate in detail

This is the core value of HLS. Here's exactly what happens as network degrades:

```
Network conditions:       Strong ──────────────────────────► Weak
Quality played:           320kbps → 256kbps → 128kbps → 64kbps
Chunk source:             high/    medium/    low/       minimum/
```

**How AVPlayer decides to switch:**

AVPlayer measures two things continuously:
- **Observed bandwidth** — how fast chunks are arriving
- **Buffer level** — how many seconds of audio are buffered ahead

```
Buffer > 30s AND bandwidth stable  → upgrade to higher quality
Buffer < 10s OR bandwidth dropping → downgrade to lower quality
Buffer = 0s                        → stall (spinner shows)
```

You don't control this logic — AVPlayer owns it. Your job is to:
1. Provide a manifest with multiple quality levels (server-side concern)
2. Observe stall events and update UI accordingly

**Observing playback state in code:**

```swift
// Observe stalls — show buffering indicator
player.observe(\.timeControlStatus) { player, _ in
    switch player.timeControlStatus {
    case .playing:
        // hide spinner
    case .waitingToPlayAtSpecifiedRate:
        // show spinner — buffering or waiting for network
    case .paused:
        // user paused or playback ended
    }
}

// Observe how much is buffered
player.observe(\.currentItem?.loadedTimeRanges) { player, _ in
    guard let range = player.currentItem?.loadedTimeRanges.first?.timeRangeValue else { return }
    let bufferedSeconds = CMTimeGetSeconds(range.start) + CMTimeGetSeconds(range.duration)
    // update buffer progress bar if you have one
}
```

**Quality floor — minimum acceptable quality:**

In the manifest, you can declare a minimum bandwidth. AVPlayer won't go below it even on terrible networks — it will stall instead of playing inaudible quality:

```
#EXT-X-STREAM-INF:BANDWIDTH=32000   ← too low — don't include this
#EXT-X-STREAM-INF:BANDWIDTH=64000   ← floor (acceptable minimum)
#EXT-X-STREAM-INF:BANDWIDTH=128000  ← standard
#EXT-X-STREAM-INF:BANDWIDTH=320000  ← high quality
```

**Preferred peak bitrate (optional override):**

You can cap quality from the client side — useful for a "data saver" mode:

```swift
player.currentItem?.preferredPeakBitRate = 128_000  // cap at 128kbps
player.currentItem?.preferredPeakBitRate = 0         // 0 = no cap (default)
```

---

### 12. Complete network failure — retry strategy

When the network cuts out entirely (airplane mode, tunnel):

```
AVPlayer behaviour:
  → Stops fetching chunks
  → Plays out existing buffer (typically 15–30s)
  → Buffer hits zero → stall → timeControlStatus = .waitingToPlayAtSpecifiedRate
  → AVPlayer automatically retries when network returns
  → Playback resumes from where it stalled
```

You don't need to implement retry logic — AVPlayer handles reconnect automatically.

What you DO need to handle:

```swift
// Detect playback ended vs stalled
NotificationCenter.default.addObserver(
    forName: .AVPlayerItemDidPlayToEndTime,
    object: player.currentItem,
    queue: .main
) { _ in
    // track finished — advance queue
}

NotificationCenter.default.addObserver(
    forName: .AVPlayerItemFailedToPlayToEndTime,
    object: player.currentItem,
    queue: .main
) { notification in
    // actual error (corrupted chunk, auth failure, etc.)
    // distinct from a stall — handle separately
}
```

**Stall vs error — important distinction:**

| Event | Cause | AVPlayer recovers? | You need to act? |
|---|---|---|---|
| `waitingToPlayAtSpecifiedRate` | Slow/no network | Yes, automatically | Show spinner only |
| `AVPlayerItemFailedToPlayToEndTime` | Corrupt chunk, 403, bad URL | No | Show error, offer retry |
| `AVPlayerItemPlaybackStalled` | Buffer ran dry | Yes, automatically | Show spinner only |

---

### 13. Common failure modes to know

| Failure | What happens | How to handle |
|---|---|---|
| Stream URL expires mid-playback | CDN returns 403 on next chunk | `StreamRefreshService` refreshes before expiry |
| Network drops mid-stream | AVPlayer stalls, `timeControlStatus == .waitingToPlayAtSpecifiedRate` | Observe `timeControlStatus`, show buffering UI |
| Offline file deleted externally | `file://` URL exists in DB but file is gone | Check file exists before handing URL to AVPlayer, fall back to stream |
| App killed during download | Partial file on disk | `DownloadTrackUseCase` / `MediaFileDataSource` checks file integrity on resume, restarts incomplete downloads |
| LRU cache full | Eviction of old chunks | Silent — user just re-downloads on next play |

---

### 14. Seeking during streaming

Seeking in a local file is trivial — just jump to a byte offset. Seeking in HLS is different because there's no single file. You're jumping between chunks.

**What happens when user drags the seek bar:**

```
User drags to 2:30 (150 seconds)

AVPlayer calculates: which chunk contains t=150s?
  chunk_001 = 0–6s
  chunk_002 = 6–12s
  ...
  chunk_025 = 144–150s   ← target chunk

AVPlayer:
  1. Discards buffered chunks ahead of current position
  2. Fetches chunk_025 from CDN
  3. Resumes buffering forward from chunk_026
  4. Playback resumes from t=150s
```

The chunk containing the seek target must be downloaded before playback can resume — this is the brief pause you see when seeking on a slow network.

---

**How to implement the seek bar:**

```swift
// 1. Track current playback time — drives the seek bar position
let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
    let currentSeconds = CMTimeGetSeconds(time)
    let duration = CMTimeGetSeconds(self?.player.currentItem?.duration ?? .zero)
    self?.progress = currentSeconds / duration   // 0.0 → 1.0
}

// 2. User finishes dragging — seek to position
func seek(to fraction: Double) {
    guard let duration = player.currentItem?.duration else { return }
    let targetSeconds = CMTimeGetSeconds(duration) * fraction
    let targetTime = CMTime(seconds: targetSeconds, preferredTimescale: 600)

    player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
        if finished {
            // seek completed — resume playback if it was playing
        }
    }
}
```

**`toleranceBefore` / `toleranceAfter` — important tradeoff:**

| Setting | Accuracy | Speed |
|---|---|---|
| `.zero` / `.zero` | Frame-accurate — seeks to exact time | Slower — must fetch the exact chunk |
| `.positiveInfinity` | Less accurate — snaps to nearest chunk boundary | Faster — may already be buffered |

For music: use `.positiveInfinity` — chunk-boundary accuracy is fine, and it's faster.  
For video scrubbing (thumbnails): use `.zero` — frame accuracy matters.

```swift
// Music — fast seek, chunk-boundary accuracy is fine
player.seek(to: targetTime, toleranceBefore: .positiveInfinity, toleranceAfter: .positiveInfinity)
```

---

**Seeking while buffering (bad network):**

```
User seeks → AVPlayer fetches target chunk → network is slow → stall

timeControlStatus = .waitingToPlayAtSpecifiedRate  ← same stall state as before
```

Handle it the same way — show a spinner, AVPlayer resumes automatically when the chunk arrives. No special seek-specific handling needed.

---

**Seeking in `PlaybackState`:**

```swift
// In PlayerService — seeking is a transient state, not a final one
func seek(to time: TimeInterval) {
    guard state.status == .playing || state.status == .paused else { return }
    let wasPlaying = state.status == .playing
    state = state.with(status: .seeking)    // UI shows seeking indicator

    audioPlayer.seek(to: time) { [weak self] in   // AudioPlayerProtocol → AudioPlayerDataSource
        // completion — restore previous state
        self?.state = self?.state.with(status: wasPlaying ? .playing : .paused)
    }
}
```

Key point: `.seeking` is transient — it always resolves back to `.playing` or `.paused`. Never leave the state stuck at `.seeking`.

---

### 15. Summary — what you own vs what frameworks own

| Responsibility | Owner |
|---|---|
| Fetching and playing chunks | AVPlayer |
| Switching quality levels | AVPlayer |
| Buffering ahead of playhead | AVPlayer |
| Deciding online vs offline path | logic inside `PlayerService` (your code) |
| Refreshing expired manifest URLs | `StreamRefreshService` (your code) |
| Writing chunks to LRU disk cache | `DownloadTrackUseCase` / `MediaFileDataSource` (your code) |
| Managing explicit offline downloads | `DownloadTrackUseCase` / `MediaFileDataSource` (your code) |
| Background audio session config | `PlayerService` at app startup (your code) |

---

## Interviewer Feedback

**Decision: Hire (Senior)**

### Rating Pillars

**1. Problem Navigation** ✅
- Drives the discussion — yes
- Asked questions to reduce ambiguity — yes
- Identifies and focuses on main problems (playback, offline support) — yes
- Good organization of the problem space — yes
- Timing — good for a 60-min interview

**2. Solution Design** ✅
- Working solution — yes
- Did well: REST API design
- Did well: Adaptive streaming with HLS
- Did well: High-level design principles
- Did well: Authentication and download URLs (short-lived signed URLs)
- ✅ **Store/Storage abstraction over DB** — `LocalDataSource` is this abstraction in Melodify; Repositories never touch UserDefaults/GRDB directly
- **Can improve: Walk through the full data flow immediately after finishing the diagram** — catches missing repo dependencies and edge cases
- Proactively handles scalability — yes
- Design with UX in mind — yes
- Deploys needed architectural patterns — yes

**3. Technical Proficiency** ✅
- Knows common frameworks and APIs — yes
- Did well: SwiftUI details, `@Observable`, async streams
- Knows modern frameworks — yes
- Identifies alternative solutions — yes
- Foresees potential points of failure — yes

**4. Technical Communication** ✅
- Responds well to questions and feedback — yes
- Explains ideas clearly and logically — yes
- Shares trade-offs and design choices — yes
- Brings relevant context — yes
- Listens carefully and willing to fix mistakes — yes

---

### Key Takeaways for Own Practice
- **State your principles first, then draw** — architecture rationale before the diagram
- **Walk the data flow end-to-end after drawing** — out loud, top to bottom, catches gaps live
- **Always add a Store/abstraction layer over the DB** — `LocalDataSource` is this layer in Melodify; Repos never touch UserDefaults/GRDB directly ✅
- **Go deep on complex topics proactively** — don't wait to be asked (e.g. signed URL expiry, offline edge cases)
