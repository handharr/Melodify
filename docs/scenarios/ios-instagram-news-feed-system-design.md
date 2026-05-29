# iOS Instagram News Feed — System Design

**Source:** YouTube — iOS System Design Interview walkthrough

> Scenario extension of [`docs/ios-app-system-design-philosophy.md`](../ios-app-system-design-philosophy.md)
> Read the delta below first.

---

## Delta — What This Scenario Adds

### Same as generic architecture

All patterns not listed above are unchanged — see [ios-app-system-design-philosophy.md](../ios-app-system-design-philosophy.md).

### What this scenario adds

| Concept | Generic | This Scenario |
|---|---|---|
| Optimistic UI | Mutation flow awaits server response | Immediate UI update on like; `LikeService` retries in background until confirmed |
| Like queue persistence | Not in generic | Core Data stores `Like { userID, postID, successfullySent }` — durable across app kills |
| Image loading | Not covered | `FeedImageDataSource` (ThirdPartyDataSource wrapping SDWebImage) — caches decoded `UIImage` on disk |
| Feed freshness | `FetchPolicy.cached` | 2-minute timestamp check before firing network (extends .cached semantics at Repository level) |
| Scroll prefetching | Not covered | `UICollectionViewDataSourcePrefetching` — start data tasks ahead of scroll, cancel for off-screen cells |
| Starvation mitigation | Not covered | Three-pronged: cancel prefetch tasks, cancel image load on cell reuse, defer new requests until scroll ends |
| Pagination | Not covered | Cursor-based with `postID` anchor, `limit=20`, `page: prev\|next` |
| Polymorphic cell UIModels | `UIModel` (flat struct per screen) | `FeedCellUIModel` enum — `.photo(PhotoCellUIModel)` / `.album(AlbumCellUIModel)` |
| UIModel mapping | ViewModel maps domain → UIModel | `FeedViewModel` maps `[Post] → [FeedCellUIModel]`; cells never receive a raw `Post` domain model |
| ViewModel as data source | ViewModel owns UIModel array | ViewModel also implements `UICollectionViewDataSource` / `UICollectionViewDelegate` directly |
| UI framework | SwiftUI default for new apps; UIKit when scroll lifecycle, AVPlayer, or custom transitions needed; hybrid valid screen-by-screen | UIKit — `UICollectionView` for prefetch lifecycle control and complex cell layout |

### Key decisions unique to this scenario

- **Cursor-based pagination over offset.** New posts arrive continuously. Offset pagination drifts — page 2 after an insertion returns one item you already saw. Cursor (`postID`) anchors to a fixed point in the feed regardless of insertions above it.
- **`LikeService` is a Domain Service, not a UseCase.** It is stateful (holds a durable retry queue), app-scoped, and long-lived — must survive foreground/background cycles. A stateless UseCase cannot hold or retry queued actions.
- **Optimistic UI with Core Data-backed queue.** The like queue (`successfullySent: false`) is persisted — not in-memory. An app kill mid-retry does not lose the user's intent. On relaunch, `LikeService` reads pending `Like` records and resumes retrying.
- **SDWebImage as `FeedImageDataSource` (ThirdPartyDataSource).** `URLCache` stores raw `Data` bytes — every display requires `UIImage(data:)`, a CPU decode hit. SDWebImage caches the already-decoded `UIImage` in memory + disk. Repeat displays are zero-cost.
- **ViewModel implements `UICollectionViewDataSource` and `UICollectionViewDelegate`.** The ViewModel already owns `items: [FeedCellUIModel]` — it is the natural place to answer "how many cells?" and "which model at index N?". Avoids a separate data source object with shared mutable state.
- **Feed freshness at the Repository, not FetchPolicy alone.** `FetchPolicy.cached` says "use local if available". This scenario adds a time constraint: local is only valid if `fetchedAt` is < 2 minutes ago. The Repository checks the timestamp before deciding whether `.cached` qualifies.

---

## Requirements

### Functional

| Requirement | Detail | Strategy |
|---|---|---|
| News feed | Vertical feed of photos and photo albums | Cursor-based pagination (`postID` anchor, `limit=20`) — stable even when new posts arrive above |
| Post content | Author avatar, name, caption, like count per post | `FeedViewModel` maps `[Post] → [FeedCellUIModel]` — cells are dumb renderers, never touch domain |
| Like / Unlike | Must work offline; retried on restore | Optimistic UI + `LikeService` durable Core Data queue (`successfullySent: false`) — resumed on relaunch |
| Infinite scroll | No visible loading gaps during fast scroll | `UICollectionViewDataSourcePrefetching` fires before cells enter viewport; SDWebImage serves decoded images from cache |
| Offline mode | Feed browsable after first load | Core Data stores `PostDTO` cache; SDWebImage disk cache stores decoded images — both survive app kills |

### Non-Functional

| Requirement | Detail | Strategy |
|---|---|---|
| Scale | ~10,000 posts in feed | Cursor pagination — never loads all posts at once; 20 per page, next page fetched on threshold |
| Smooth scrolling | No frame drops during fast scroll | Prefetch images ahead of viewport + cancel off-screen tasks + SDWebImage zero-decode display (decoded `UIImage` already in memory) |
| Network resilience | No starvation of visible cells; graceful degradation | Three-pronged cancellation (prefetch cancel, cell reuse cancel, defer on scroll); 2-minute TTL with Core Data offline fallback |

---

## API Design

**Strategy:** REST + cursor-based pagination. Authentication assumed.

```
GET /users/<userID>/feed
  Params:
    postID  — cursor (ID of last seen post)
    limit   — Int (20)
    page    — "prev" | "next"
  Response:
    posts: [PostDTO]
    nextCursor: String?

POST /users/<userID>/likes
  Body:
    [{ postID: Int, value: Bool }]
  Response: 204 No Content
```

**Why cursor over offset?** If 5 posts arrive while the user is on page 2, offset page 3 overlaps with what was page 2 — the user sees duplicates. Cursor anchors to `postID`, immune to insertions above the anchor.

**Why batch likes (array body)?** A user who likes several posts while offline sends one request on restore instead of N. Reduces reconnect burst.

**Image URLs in response, not binary data.** `PostDTO.photoURLs` contains S3 URLs. The API stays lightweight; SDWebImage resolves images independently via `FeedImageDataSource`.

---

## Data Model

### Domain Models

```swift
struct Post {
    let postID: Int
    let type: PostType          // .photo | .album
    let author: User
    let likeCount: Int
    let caption: String
    let location: String?
    let photoURLs: [URL]
}

enum PostType { case photo, album }

struct User {
    let userID: Int
    let name: String
    let avatarURL: URL
}

struct Like {
    let userID: Int
    let postID: Int
    var successfullySent: Bool  // false = pending retry
}
```

### DTO (mirrors API shape)

```swift
struct PostDTO: Codable {
    let postID: Int
    let type: Int               // 0 = photo, 1 = album
    let authorID: Int
    let likeCount: Int
    let caption: String
    let location: String?
    let photoURLs: [String]
}
```

### UIModels (Presentation layer only)

```swift
enum FeedCellUIModel {
    case photo(PhotoCellUIModel)
    case album(AlbumCellUIModel)
}

struct PhotoCellUIModel {
    let title: String
    let avatarURL: URL
    let imageURL: URL
    let likeCount: Int
    var isLiked: Bool
}

struct AlbumCellUIModel {
    let title: String
    let avatarURL: URL
    let imageURLs: [URL]
    let likeCount: Int
    var isLiked: Bool
}
```

`FeedCellUIModel` is an enum — the compiler enforces exhaustive handling. Cells never inspect `Post` directly.

---

## Architecture

```
Presentation    →  ViewController + FeedViewModel (@MainActor)
                   FeedViewModel implements UICollectionViewDataSource + UICollectionViewDelegate
Domain          →  FetchFeedUseCase · LikePostUseCase · LikeService (app-scoped)
Data            →  NewsFeedRepository · LikeRepository
                   FeedRemoteDataSource · FeedLocalDataSource (Core Data)
                   FeedImageDataSource (wraps SDWebImage — single-layer Data concern)
Infrastructure  →  None
External        →  SDWebImage · CoreData · URLSession · Network.framework
Application     →  AppDelegate · AppCoordinator · manual init injection
```

**Layer dependency rule: Presentation → Domain ← Data. Domain depends on nothing.**

### Layer Breakdown

| Layer | Components |
|---|---|
| Presentation | `FeedViewController`, `FeedViewModel`, `FeedCellUIModel` (enum), `PhotoCell`, `AlbumCell` |
| Domain | `FetchFeedUseCase`, `LikePostUseCase`, `LikeService`, `Post`, `User`, `Like`, `FeedParam` |
| Data | `NewsFeedRepository`, `LikeRepository`, `FeedRemoteDataSource`, `LikeRemoteDataSource`, `FeedLocalDataSource`, `FeedImageDataSource`, `PostDTO`, `PostMapper` |
| Infrastructure | None |
| External | `SDWebImage` · `CoreData` · `URLSession` · `Network.framework` |
| Application | `AppCoordinator`, `AppDelegate` |

### Architecture Diagram

```
FeedViewController
    │
    ▼
FeedViewModel (@MainActor)
    │  items: [FeedCellUIModel]
    │  implements UICollectionViewDataSource + UICollectionViewDelegate
    │
    ├──► FetchFeedUseCase
    │       └─► NewsFeedRepository
    │               ├─► FeedRemoteDataSource ─── GET /users/<id>/feed ──► REST API
    │               └─► FeedLocalDataSource (Core Data — metadata cache)
    │
    └──► LikeService (app-scoped singleton)
             └─► LikeRepository
                     ├─► LikeRemoteDataSource ── POST /users/<id>/likes ──► REST API
                     └─► FeedLocalDataSource (Core Data — Like queue, successfullySent flag)

FeedViewModel ──► FeedImageDataSource (SDWebImage) ──► S3 URLs (photoURLs from PostDTO)

> Note: Cells receive pre-resolved image URLs via `FeedCellUIModel`; `FeedImageDataSource` is called by `FeedRepository` (or the ViewModel via a dedicated use case), not by cells directly.
```

### Dependency Injection (Composition Root)

No DI framework. Dependencies flow inward via init. `AppCoordinator` owns the composition root — it builds the full graph and holds app-scoped objects as strong properties.

```swift
// AppCoordinator — composition root
let client = APIClient()

// Data layer
let feedRemoteDS = FeedRemoteDataSource(client: client)
let likeRemoteDS = LikeRemoteDataSource(client: client)
let feedLocalDS  = FeedLocalDataSource()              // wraps Core Data

// Repositories
let newsFeedRepo = NewsFeedRepository(remote: feedRemoteDS, local: feedLocalDS)
let likeRepo     = LikeRepository(remote: likeRemoteDS, local: feedLocalDS)

// Domain Services — strong property on AppCoordinator; survives screen transitions
let likeService  = LikeService(repository: likeRepo)
likeService.resumePendingRetries()                    // re-queue successfullySent=false on launch

// UseCases — stateless; created per-navigation
let fetchFeedUseCase = FetchFeedUseCase(repository: newsFeedRepo)

// Presentation — created by Coordinator when pushing feed screen
let viewModel = FeedViewModel(
    fetchFeed: fetchFeedUseCase,
    likeService: likeService
)
```

`LikeService` is a stored property on `AppCoordinator`, not created inside `FeedViewController`. This is what keeps it alive across screen transitions and app lifecycle events. If it were owned by the ViewController, it would deallocate on pop and lose the retry queue.

---

## Data Flow

### Feed Load Flow

Two cache layers operate independently on every launch. Feed metadata (Core Data, 2-minute TTL) and images (SDWebImage disk cache, session-independent) are never coupled.

```
FeedViewController.viewDidLoad()
    → FeedViewModel.load()
        → isLoading = true
        → FetchFeedUseCase.execute(policy: .cached, param: FeedParam(userID:))
            → NewsFeedRepository.fetch(policy: .cached, param:)
                → FeedLocalDataSource.fetchedAt age check
                    │
                    ├── age < 2 min (active session, e.g. pulled back to feed)
                    │       → return cached PostDTOs from Core Data
                    │       → no network call ✅
                    │
                    └── age >= 2 min (relaunch, background restore, next day)
                            → FeedRemoteDataSource.fetch()
                                → GET /users/<id>/feed?limit=20   ← no cursor, fresh start
                                    → response: PostDTO[1..20] with current likeCount
                                    → PostMapper.toDomain([PostDTO]) → [Post]
                                    → FeedLocalDataSource.save(dtos)   ← overwrites stale cache
                                    → fetchedAt = now
                            // Offline path: network fails → serve stale Core Data anyway
                            //   user sees yesterday's posts, no crash, no empty state

        → FeedViewModel maps [Post] → [FeedCellUIModel]
        → @Published items updated → UICollectionView reloads

        // Image layer resolves independently — no involvement from Repository
        Cell becomes visible → imageView.sd_setImage(with: post.imageURL)
            → SDWebImage disk cache check (keyed by S3 URL)
                ├── HIT  (same URL as yesterday) → decoded UIImage, zero network ✅
                └── MISS (new post / evicted)    → download → decode → cache → display
        → defer: isLoading = false
```

**Why the two layers are decoupled:** Core Data holds post metadata (text, counts, URLs). SDWebImage holds decoded images keyed by the URLs inside those DTOs. Even when Core Data is stale and triggers a network re-fetch, the response contains the same S3 URLs as yesterday — SDWebImage recognises them and serves from disk. Metadata freshness and image freshness have independent clocks.

### Like Flow (Optimistic, Offline-Safe)

```
User taps like on post at index i
    → FeedViewModel.toggleLike(at: i)
        → items[i] optimistically mutated (toggle isLiked, ±1 likeCount)  ← instant UI
        → LikeService.enqueue(Like { userID, postID, successfullySent: false })
            → FeedLocalDataSource.save(Like)  ← persisted to Core Data
            → LikeRemoteDataSource.post([{ postID, value }])
                // (userID, postID) is a natural idempotency key — the server treats duplicate
                // like requests as no-ops. No explicit client UUID needed.
                → success: FeedLocalDataSource.update(Like, successfullySent: true)
                → failure: leave successfullySent = false
                    → background retry loop on connectivity restore (NetworkPathDataSource monitors NWPathMonitor)
```

### Scroll Prefetch Flow

Two systems run in parallel during a scroll gesture: **image prefetching** (per-cell, SDWebImage) and **page prefetching** (cursor pagination). Both must work together for zero-gap scrolling.

```
─────────────────────────────────────────────────────────────────────
SYSTEM A — Image Prefetch  (fires while cells are still off-screen)
─────────────────────────────────────────────────────────────────────

User scrolls down — cells 6, 7 approaching viewport but not yet visible
    │
    ▼
UICollectionView.prefetchItemsAt([IndexPath(6), IndexPath(7)])
    → FeedViewModel.prefetch(at: indexPaths)
        → withThrowingTaskGroup {
            task A1: FeedImageDataSource.load(url: items[6].imageURL)
            task A2: FeedImageDataSource.load(url: items[7].imageURL)
            // Dynamic N cells → withThrowingTaskGroup (not async let — N is not known at compile time)
          }
          → SDWebImage: download bytes → decode UIImage in background thread
          → store decoded UIImage in memory cache + disk cache
          // All this happens BEFORE cell 6 enters the viewport

Cell 6 becomes visible → UICollectionView.cellForItemAt(6)
    → PhotoCell.configure(model: items[6])
        → imageView.sd_setImage(with: items[6].imageURL)
            → SDWebImage: memory cache HIT — decoded UIImage already present
            → zero network · zero decode · instant display ✅


─────────────────────────────────────────────────────────────────────
SYSTEM B — Page Prefetch  (fires when user approaches end of page)
─────────────────────────────────────────────────────────────────────

items[] currently has 20 posts (page 1, cursor = postID_20)
User scrolls — cell 17 enters viewport (4 cells from end)
    │
    ▼
FeedViewModel.collectionView(_:willDisplay:forItemAt:)
    → detects: indexPath.row >= items.count - 5  ← threshold: last 5 cells
    → FetchFeedUseCase.execute(policy: .fresh, param: FeedParam(cursor: lastPostID))
        → NewsFeedRepository.fetch(policy: .fresh, param:)
            → FeedRemoteDataSource.fetch()
                → GET /users/<id>/feed?postID=20&limit=20&page=next
                    → response: PostDTO[21...40], nextCursor: "postID_40"
                    → PostMapper.toDomain([PostDTO]) → [Post]
                    → FeedLocalDataSource.save(dtos)  ← write-through cache
        → FeedViewModel maps [Post] → [FeedCellUIModel]
        → items.append(contentsOf: newItems)  ← items[] now has 40 entries
        → UICollectionView.insertItems(at: [IndexPath(20)...IndexPath(39)])
            // insert not reload — preserves scroll position ✅

User reaches cell 20 → cell 21 already in items[], no spinner ✅


─────────────────────────────────────────────────────────────────────
CANCELLATION — fast scroll starvation prevention
─────────────────────────────────────────────────────────────────────

User flicks rapidly: cells 1→50 in 200ms
    → prefetchItemsAt fires for every approaching cell
    → request queue: [img_1][img_2]...[img_50] — bandwidth split 50 ways
    → cell 48 (visible) starves behind 47 stale requests ← PROBLEM

Fix A — Cancel off-screen prefetch tasks:
UICollectionView.cancelPrefetchingForItemsAt([IndexPath(1), IndexPath(2), ...])
    → FeedViewModel.cancelPrefetch(at: indexPaths)
        → prefetchTasks[indexPath]?.cancel()  ← Swift Task cancelled
        → bandwidth released to tasks near current viewport

Fix B — Cancel on cell reuse:
Cell.prepareForReuse()
    → imageView.sd_cancelCurrentImageLoad()  ← kills stale SDWebImage request
    // Recycled cell drops wrong-post request before new configure() is called

Fix C — Defer requests until scroll settles (optional):
scrollViewDidEndDecelerating()
    → resume prefetch tasks for currently visible + approaching cells only
    // During deceleration: no new requests fired, all bandwidth to visible cells


─────────────────────────────────────────────────────────────────────
TIMELINE — one full scroll gesture (happy path)
─────────────────────────────────────────────────────────────────────

T=0ms    User starts scrolling down
T=10ms   prefetchItemsAt([8,9,10]) → 3 SDWebImage tasks start concurrently
T=50ms   User scrolls faster — cells 3,4 exit prefetch window
         cancelPrefetchingForItemsAt([3,4]) → tasks cancelled, bandwidth freed
T=100ms  Cell 6 enters reuse pool → prepareForReuse() → sd_cancelCurrentImageLoad()
T=150ms  Cell 8 becomes visible → sd_setImage() → memory cache HIT → instant ✅
T=200ms  Cell 17 visible (4 from end) → page fetch fires → GET next cursor
T=300ms  Posts 21–40 arrive → appended → items[] = 40 entries
T=350ms  User reaches cell 20 → cell 21 already rendered, no gap ✅
```

---

## Deep Dives

### Cursor-Based Pagination

```
Offset (breaks on live feed):
  Page 1: [A B C D E F G H I J]  → page 2 offset=10
  New post "X" inserted at top
  Page 2: [F G H I J K ...]       ← F already seen — duplicate!

Cursor (stable):
  Page 1: [A B C D E F G H I J]  → nextCursor = "J"
  New post "X" inserted at top
  Page 2 (cursor=J): [K L M ...]  ← starts after J, unaffected
```

The cursor is an opaque value — `postID` here, but the client treats it as a black box. Never parse or construct it on the client.

### Image Cache: SDWebImage vs URLCache

| | URLCache | SDWebImage |
|---|---|---|
| Stores | Raw `Data` (HTTP bytes) | Decoded `UIImage` object |
| Display cost | `UIImage(data:)` every time | Zero — object already decoded |
| Thread | Main thread decode risk | Background decode, main thread display |
| Disk | Yes | Yes (separate disk cache) |
| Memory | NSURLCache LRU | NSCache (auto-evict under pressure) |

SDWebImage is wrapped as `FeedImageDataSource: ImageDataSourceProtocol`. The rest of the app calls the protocol — never SDWebImage directly. Swapping the library = one file change.

### Resource Starvation Mitigation

When a user flicks through the feed rapidly, hundreds of image requests queue up for cells that are no longer visible. Visible cells starve.

Three-pronged fix:
1. **Cancel prefetch tasks** — implement `cancelPrefetchingForItemsAt`. Stop data tasks for IndexPaths no longer approaching the viewport.
2. **Cancel on cell reuse** — `prepareForReuse` calls `sd_cancelCurrentImageLoad()`. Prevents a recycled cell from showing the wrong post's image.
3. **Defer new requests until scroll settles** — optionally, only fire new data tasks in `scrollViewDidEndDecelerating`. Bandwidth goes to what the user is actually reading.

### Feed Freshness — Extending FetchPolicy.cached

The generic architecture's `FetchPolicy.cached` returns local data if any exists. This scenario adds a time constraint: local data is only valid if `fetchedAt < 2 minutes ago`.

Implementation: `FeedLocalDataSource` stores a `fetchedAt: Date` alongside the cached DTOs (either in a Core Data entity field or UserDefaults). `NewsFeedRepository` reads `fetchedAt` before deciding whether `.cached` qualifies.

```swift
// Inside NewsFeedRepository.fetch(policy:param:)
if policy == .cached {
    let age = Date().timeIntervalSince(localDataSource.fetchedAt ?? .distantPast)
    if age < 120 { return localDataSource.fetchAll() }  // serve from cache
}
// else: fall through to network
```

#### Two Cache Layers, Independent Clocks

The 2-minute TTL only governs feed metadata. Images have a separate lifecycle entirely.

| | Feed metadata (Core Data) | Images (SDWebImage disk) |
|---|---|---|
| Stores | PostDTO — text, counts, S3 URLs | Decoded `UIImage` keyed by URL |
| TTL | 2 minutes (`fetchedAt`) | Days / weeks (SDWebImage config) |
| Scope | Per-feed fetch | Per-URL, session-independent |
| On relaunch | Stale → re-fetch from network | Disk cache intact → instant display |
| Offline | Serve stale DTOs from Core Data | Serve decoded images from disk |

**Key insight:** after a network re-fetch of metadata, the response contains the same S3 URLs as yesterday. SDWebImage recognises those URLs and serves decoded images from disk — no image re-download required even when metadata is completely refreshed.

#### Feed-Level TTL vs Per-Post TTL

| | Feed-level TTL (current) | Per-post TTL |
|---|---|---|
| Granularity | One `fetchedAt` for whole page | Each `PostDTO` has own `expiresAt` |
| Re-fetch unit | All 20 posts at once | Only stale individual posts |
| Complexity | Simple — one timestamp | N timestamps in Core Data |
| Use case | Social feed, like counts | Prices, seat counts, inventory |

Per-post TTL is overkill for a social feed. Like counts stale by < 2 minutes is acceptable UX. Feed-level TTL wins on simplicity.

#### Within-Session Staleness (the 2-minute window)

```
T=0min   App opens → network fetch → post_1 { likeCount: 42, fetchedAt: now }
T=1min   1,000 users like post_1 → server: likeCount = 1042
T=1.5min User scrolls back to post_1
         fetchedAt age = 1.5min < 2min → serve cache → shows likeCount: 42 ← stale
T=2min   fetchedAt expires → next load triggers re-fetch → likeCount: 1042 ✅
```

Staleness window = 2 minutes max. Acceptable for social content — not for stock prices. The user's own like is always instant via optimistic UI regardless of this window.

### Optimistic UI + Durable Like Queue

The generic mutation flow: ViewModel → UseCase → Repository → server, then update UI on response.

This scenario inverts the order for likes: UI updates first, server is eventual.

The `Like.successfullySent` flag bridges the two worlds:
- `false` = pending, persist to Core Data, enqueue retry
- `true` = confirmed, clean up record

On app relaunch, `LikeService` reads all `Like` records with `successfullySent = false` from `FeedLocalDataSource` and resumes retrying. The queue is durable — not session-scoped.

Open question: retry policy (exponential back-off vs fixed interval, retry cap) is not specified by the video. Worth having a position: exponential back-off with a 3-attempt cap, then surface an error to the user.

---

## Pitfalls / Gotchas

- **Using `URLCache` for images.** It stores raw bytes — you decode on every display. Use SDWebImage via `FeedImageDataSource`.
- **Offset pagination on a live feed.** Insertions at the top shift offsets — duplicates appear. Use cursor-based pagination.
- **Not implementing `cancelPrefetchingForItemsAt`.** Stale requests pile up and starve visible cells. Always pair `prefetchItemsAt` with its cancel counterpart.
- **Forgetting `sd_cancelCurrentImageLoad()` in `prepareForReuse`.** Fast scrollers see wrong images briefly — the recycled cell shows the previous request's result.
- **Creating `LikeService` inside a ViewController instead of the composition root.** If `FeedViewController` owns it, the service deallocates on pop — the retry queue is lost. It must be a stored property on `AppCoordinator`, passed down via init injection.
- **`successfullySent` records never cleaned up.** The retry loop must set `successfullySent = true` and eventually delete the record on success, or the Core Data queue grows unbounded.
- **`LikeService` owned by a ViewController.** If scoped to a screen, it deallocates when the user navigates away — the retry queue disappears. Register at AppCoordinator level, same as `PlayerService` in the music streaming scenario.

---

## Interviewer Talking Points

- "I'd use cursor-based pagination — it's stable when new posts arrive, unlike offset which drifts and causes duplicates or skips."
- "The `Like` domain model carries a `successfullySent` flag. `LikeService` updates the UI optimistically and retries in the background until the flag flips to true."
- "For image caching I'd wrap SDWebImage in a `FeedImageDataSource` — it caches the decoded `UIImage`, so repeat displays are zero-cost. `URLCache` stores raw bytes and you pay the decode hit every time."
- "I'd use `UICollectionView` with `UICollectionViewDataSourcePrefetching`. That protocol gives me `cancelPrefetchingForItemsAt` — without it, rapid scrolling queues hundreds of stale requests and starves visible cells."
- "The ViewModel maps `Post` domain objects into typed `FeedCellUIModel` variants before the collection view sees them. Cells are dumb renderers — they never touch the domain layer."
- "The like queue is persisted to Core Data with `successfullySent: false`. An app kill mid-retry doesn't lose the user's intent — `LikeService` reads pending records on relaunch and resumes."
- "Feed freshness extends `FetchPolicy.cached` with a 2-minute timestamp. If `fetchedAt` is recent, skip the network. The Repository is the only place that reads this timestamp."

---

## Open Questions

- **Retry policy for failed likes:** Back-off strategy (fixed vs exponential), retry cap, and what to show the user after exhausting retries — not defined in the video. Suggested position: 3 attempts with exponential back-off, then surface a non-blocking error banner.
- **Exact prefetch trigger threshold:** How many cells from the bottom to fire the next cursor page request — `UICollectionViewDataSourcePrefetching` provides the hook but the threshold is a product decision (e.g., last 5 cells = ~25% of one page).
- **Feed refresh UI transition:** Full reload vs `NSDiffableDataSourceSnapshot` diff on cache expiry. Diff avoids flash; full reload is simpler.
- **Cache timestamp storage:** `fetchedAt` can live as a Core Data entity field on a `FeedMetadata` record, or in `UserDefaults` keyed by `userID`. Either works; UserDefaults is simpler.
- **Network restoration trigger for `LikeService`:** Resolved — `NWPathMonitor` (Network.framework). Per philosophy rules, non-UIKit/SwiftUI/Combine frameworks must always be wrapped. `NWPathMonitor` is Presentation-free (connectivity state only) → wraps as `NetworkPathDataSource` in the Data layer. Added to External layer table: `Network.framework → NetworkPathDataSource (Data)`.
