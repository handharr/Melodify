# iOS Instagram News Feed — System Design

**Source:** YouTube — iOS System Design Interview walkthrough

> Scenario extension of [`docs/ios-app-system-design-philosophy.md`](../ios-app-system-design-philosophy.md)
> Read the delta below first.

---

## Delta — What This Scenario Adds

### Same as generic architecture

- Clean Architecture + MVVM + UIKit
- DTO → Mapper → Domain Model
- `FetchPolicy` (.fresh / .cached / .strict) on all Repository reads
- Typed `Param` structs on every UseCase
- `@MainActor` on ViewModel — all state mutations on main thread
- `defer { isLoading = false }` — guaranteed cleanup on success and failure
- `[weak self]` in all closures
- Coordinator-based navigation, manual init injection (no DI framework)
- Mock-the-layer-below testing strategy
- `ThirdPartyDataSource` pattern — wraps third-party SDKs; app never calls SDK directly
- `async/await` for I/O; Combine for reactive binding to `@Published` state
- Idempotency keys on mutations — client-generated UUID at `Param` call site for any retryable mutation
- HTTP `409 ≠ 5xx` — concurrency conflicts and transient server errors must never share a code path
- Infrastructure layer (`Gateway` suffix) — Gateway trigger is cross-layer span, not SDK imports; single-layer SDKs wrap in their natural layer (DataSource or Service); Domain defines protocol; concrete in Infrastructure; nothing depends on Gateway except DI wiring in Application
- External layer (outermost ring) — actual SDKs and OS frameworks; UIKit / SwiftUI / Combine need no wrapper (reactive/UI primitives used directly); all other SDKs always wrapped; wrapper placement scope-based: single-layer SDK → DataSource or Service, cross-layer SDK → Gateway in Infrastructure

### What this scenario adds

| Concept | Generic | This Scenario |
|---|---|---|
| Optimistic UI | Mutation flow awaits server response | Immediate UI update on like; `LikeService` retries in background until confirmed |
| Like queue persistence | Not in generic | Core Data stores `Like { userID, postID, successfullySent }` — durable across app kills |
| Image loading | Not covered | `ImageSDKDataSource` (ThirdPartyDataSource wrapping SDWebImage) — caches decoded `UIImage` on disk |
| Feed freshness | `FetchPolicy.cached` | 2-minute timestamp check before firing network (extends .cached semantics at Repository level) |
| Scroll prefetching | Not covered | `UICollectionViewDataSourcePrefetching` — start data tasks ahead of scroll, cancel for off-screen cells |
| Starvation mitigation | Not covered | Three-pronged: cancel prefetch tasks, cancel image load on cell reuse, defer new requests until scroll ends |
| Pagination | Not covered | Cursor-based with `postID` anchor, `limit=20`, `page: prev\|next` |
| Polymorphic cell UIModels | `UIModel` (flat struct per screen) | `FeedCellUIModel` enum — `.photo(PhotoCellUIModel)` / `.album(AlbumCellUIModel)` |
| ViewModel as data source | ViewModel owns UIModel array | ViewModel also implements `UICollectionViewDataSource` / `UICollectionViewDelegate` directly |
| UI framework | SwiftUI default for new apps; UIKit when scroll lifecycle, AVPlayer, or custom transitions needed; hybrid valid screen-by-screen | UIKit — `UICollectionView` for prefetch lifecycle control and complex cell layout |

### Key decisions unique to this scenario

- **Cursor-based pagination over offset.** New posts arrive continuously. Offset pagination drifts — page 2 after an insertion returns one item you already saw. Cursor (`postID`) anchors to a fixed point in the feed regardless of insertions above it.
- **`LikeService` is a Domain Service, not a UseCase.** It is stateful (holds a durable retry queue), app-scoped, and long-lived — must survive foreground/background cycles. A stateless UseCase cannot hold or retry queued actions.
- **Optimistic UI with Core Data-backed queue.** The like queue (`successfullySent: false`) is persisted — not in-memory. An app kill mid-retry does not lose the user's intent. On relaunch, `LikeService` reads pending `Like` records and resumes retrying.
- **SDWebImage as `ImageSDKDataSource` (ThirdPartyDataSource).** `URLCache` stores raw `Data` bytes — every display requires `UIImage(data:)`, a CPU decode hit. SDWebImage caches the already-decoded `UIImage` in memory + disk. Repeat displays are zero-cost.
- **ViewModel implements `UICollectionViewDataSource` and `UICollectionViewDelegate`.** The ViewModel already owns `items: [FeedCellUIModel]` — it is the natural place to answer "how many cells?" and "which model at index N?". Avoids a separate data source object with shared mutable state.
- **Feed freshness at the Repository, not FetchPolicy alone.** `FetchPolicy.cached` says "use local if available". This scenario adds a time constraint: local is only valid if `fetchedAt` is < 2 minutes ago. The Repository checks the timestamp before deciding whether `.cached` qualifies.

---

## Requirements

### Functional

- Vertical news feed of posts: photos and photo albums
- Each post: author avatar, author name, caption, like count
- Like / unlike a post — must work offline (optimistic, retried on restore)
- Fast infinite scroll with no visible loading gaps
- Offline mode: feed browsable after first load

### Non-Functional

- Scale baseline: ~10,000 posts in feed
- Smooth scrolling: no frame drops during fast scroll
- Network resilience: graceful degradation; no starvation of visible cells

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

**Image URLs in response, not binary data.** `PostDTO.photoURLs` contains S3 URLs. The API stays lightweight; SDWebImage resolves images independently via `ImageSDKDataSource`.

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
                   ImageSDKDataSource (wraps SDWebImage — single-layer Data concern)
Infrastructure  →  None
External        →  SDWebImage (via ImageSDKDataSource · Data) · CoreData (via FeedLocalDataSource · Data) · URLSession (via APIClient · Data)
Application     →  AppDelegate · AppCoordinator · manual init injection
```

**Layer dependency rule: Presentation → Domain ← Data. Domain depends on nothing.**

### Layer Breakdown

| Layer | Components |
|---|---|
| Presentation | `FeedViewController`, `FeedViewModel`, `FeedCellUIModel` (enum), `PhotoCell`, `AlbumCell` |
| Domain | `FetchFeedUseCase`, `LikePostUseCase`, `LikeService`, `Post`, `User`, `Like`, `FeedParam` |
| Data | `NewsFeedRepository`, `LikeRepository`, `FeedRemoteDataSource`, `LikeRemoteDataSource`, `FeedLocalDataSource`, `PostDTO`, `PostMapper` |
| Infrastructure | None — SDWebImage is a single-layer SDK; no cross-layer wrappers in this scenario |
| External | `SDWebImage` → `ImageSDKDataSource` (Data) · `CoreData` → `FeedLocalDataSource` (Data) · `URLSession` → `APIClient` (Data) |
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

Cells ──► ImageSDKDataSource (SDWebImage) ──► S3 URLs (photoURLs from PostDTO)
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

```
FeedViewController.viewDidLoad()
    → FeedViewModel.load()
        → isLoading = true
        → FetchFeedUseCase.execute(policy: .cached, param: FeedParam(userID:))
            → NewsFeedRepository.fetch(policy: .cached, param:)
                → FeedLocalDataSource.fetchedAt → if < 2 min → return cached DTOs
                → else: FeedRemoteDataSource.fetch() → GET /users/<id>/feed?postID=<cursor>&limit=20
                    → response → PostDTO array
                    → PostMapper.toDomain(dto) → [Post]
                    → FeedLocalDataSource.save(dtos)  ← write-through cache
        → FeedViewModel maps [Post] → [FeedCellUIModel]
        → @Published items updated → UICollectionView reloads
        → defer: isLoading = false
```

### Like Flow (Optimistic, Offline-Safe)

```
User taps like on post at index i
    → FeedViewModel.toggleLike(at: i)
        → items[i] optimistically mutated (toggle isLiked, ±1 likeCount)  ← instant UI
        → LikeService.enqueue(Like { userID, postID, successfullySent: false })
            → FeedLocalDataSource.save(Like)  ← persisted to Core Data
            → LikeRemoteDataSource.post([{ postID, value }])
                → success: FeedLocalDataSource.update(Like, successfullySent: true)
                → failure: leave successfullySent = false
                    → background retry loop on connectivity restore
```

### Scroll Prefetch Flow

```
UICollectionView triggers prefetchItemsAt(indexPaths:)
    → FeedViewModel.prefetch(at: indexPaths)
        → for each indexPath: start background data task (if not already fetched)

UICollectionView triggers cancelPrefetchingForItemsAt(indexPaths:)
    → FeedViewModel.cancelPrefetch(at: indexPaths)
        → cancel pending data tasks for those indexPaths

Cell.prepareForReuse()
    → imageView.sd_cancelCurrentImageLoad()   ← cancel stale SDWebImage request
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

SDWebImage is wrapped as `ImageSDKDataSource: ImageDataSourceProtocol`. The rest of the app calls the protocol — never SDWebImage directly. Swapping the library = one file change.

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

- **Using `URLCache` for images.** It stores raw bytes — you decode on every display. Use SDWebImage via `ImageSDKDataSource`.
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
- "For image caching I'd wrap SDWebImage in an `ImageSDKDataSource` — it caches the decoded `UIImage`, so repeat displays are zero-cost. `URLCache` stores raw bytes and you pay the decode hit every time."
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
- **Network restoration trigger for `LikeService`:** `NWPathMonitor` (modern, built-in, no third-party) vs Reachability (legacy). Prefer `NWPathMonitor`.
