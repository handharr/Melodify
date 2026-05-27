# iOS Story Viewer — System Design

**Source:** YouTube — iOS System Design Interview: Story Viewer

> Scenario extension of [`docs/ios-app-system-design-philosophy.md`](../ios-app-system-design-philosophy.md)
> Read the delta below first.

---

## Delta — What This Scenario Adds

### Same as generic architecture

- Clean Architecture + MVVM + UIKit
- DTO → Mapper → Domain Model
- Typed `Param` structs on every UseCase
- `@MainActor` on ViewModel — all state mutations on main thread
- `defer { isLoading = false }` — guaranteed cleanup on success and failure
- `[weak self]` in all closures
- Coordinator-based navigation, manual init injection (no DI framework)
- Mock-the-layer-below testing strategy
- `async/await` for I/O; Combine for reactive binding to `@Published` state
- Infrastructure: no Gateway needed — `StoryImageDataSource` (SDWebImage) is a single-layer Data concern.
- External: `SDWebImage` · `CoreData / JSON` · `URLSession` — all wrapped per philosophy doc rules.
- UIModel — `StoryViewModel` maps `Story` → `StoryUIModel`; View never receives raw `Story` domain models.
- Idempotency keys on mutations — client-generated UUID at `Param` call site for any retryable mutation
- HTTP `409 ≠ 5xx` — concurrency conflicts and transient server errors must never share a code path

### What this scenario adds

| Concept | Generic | This Scenario |
|---|---|---|
| API strategy | Cursor or offset pagination | Single endpoint `getStoriesAfter(cursor:)` — full load + delta in one call |
| Domain Service | `SessionService` / `PlayerService` examples | `StoryOrderService` — stateful ranking (unseen-first) + `markAsSeen` tracking |
| Image loading | Not covered | `StoryImageDataSource` (wraps SDWebImage) — caches decoded `UIImage`, background download |
| Image pre-fetching | Not covered | ViewModel triggers prefetch for `nextStory` on every display cycle |
| UI carousel pattern | Not covered | Three recycled `UIImageView` instances with swipe gesture — seamless infinite loop |
| Auto-advance | Not covered | 10-second timer in ViewController, **started after image download completes** (not on transition) |
| Story expiry | Not covered | Repository filters `expireAt < now` before returning Domain models |
| Throttle guard | FetchPolicy handles cache/network split | `FetchPolicy.cached` at Repository — skips network if local data is < 10 min old |
| FetchPolicy interpretation | Generic: return cache if available, else network | `.cached` augmented: `StoryRepository` enforces 10-minute freshness window; Repository is the only interpreter; ViewModel never decides the time threshold. |
| Concurrency | Generic: `async let` (2–3), `withThrowingTaskGroup` (N) | Loads are sequential — no parallel awaits; Pattern A (two-await cache-then-network) not applied because the 10-minute throttle guard eliminates the two-phase need. |

### Key decisions unique to this scenario

- **No pagination.** Stories are 24-hour bounded. The full metadata response is ~50 KB. A single `getStoriesAfter(cursor:)` endpoint handles both initial load (cursor = nil) and delta updates (cursor = latest known ID).
- **`StoryOrderService` is a Domain Service, not a UseCase.** It is stateful (holds `seenStoryIDs: Set<String>`) and lives beyond a single user action — it must survive a foreground/background cycle and be consulted on every swipe. Fails both UseCase criteria (stateless, triggered per user action).
- **Three-UIImageView recycling, not UICollectionView or UIPageViewController.** Both standard containers struggle with seamless wrap-around (last → first story). Manual view recycling gives precise frame-level control over the loop animation.
- **Timer tied to download, not to transition.** Starting the 10-second auto-advance timer before the image loads burns the user's viewing window on a spinner. The timer starts only after SDWebImage signals download completion.
- **SDWebImage wrapped as `StoryImageDataSource`.** The rest of the app calls `ImageDataSourceProtocol` — never SDWebImage directly. Swapping the library = one file change.

---

## Requirements

### Functional
- Full-screen story slideshow: swipe left/right or auto-advance every 10 seconds
- Stories expire 24 hours after posting; expired stories must not be displayed
- "Next" story = most recently posted unseen story (unseen-first, recency sort)
- Once the last story is reached, loop back to the first (infinite scroll)
- Offline mode: cached stories remain browsable without connectivity
- Each story shows: photo, author avatar, author name, timestamp

### Non-Functional
- Smooth UI: no frame drops during swipe; no visible spinners mid-session
- Network resilience: graceful degradation on slow or intermittent connections
- Storage efficiency: limited device storage; avoid redundant image caching
- Backend efficiency: no redundant API calls; throttled polling

---

## API Design

### Endpoint

```
GET /stories?after={photoID}
```

| Parameter | Type | Description |
|---|---|---|
| `after` | `Int?` | ID of the most recent locally known story. Omit for initial load. |

**Response:** array of `StoryDTO` objects — newest-first, covering all unexpired stories posted after the cursor.

**Initial load (cursor = nil):** returns all stories from the last 24 hours.
**Delta load (cursor = N):** returns only stories posted after ID N.

### Why not cursor-based pagination?

Classic pagination (`initialLoad(pageSize)` / `headLoad(pageSize, cursor)` / `tailLoad(pageSize, cursor)`) is designed for feeds of arbitrary depth. Stories are time-bounded (24 h). The full dataset is ~50 KB uncompressed — fits in a single response. Pagination adds three endpoints and client-side merging complexity for no benefit.

### Capacity estimate

```
100 bytes/field × 500 stories × ~0.25 compression ratio × 4 string fields ≈ 50,000 bytes ≈ 50 KB
```

Images are **not** in the metadata response. They are served from Amazon S3. The API returns a URL string; the client fetches image binary lazily via `StoryImageDataSource`.

---

## Data Model

### Domain Model

```swift
struct Story {
    let id: Int
    let photoURL: URL
    let profilePicURL: URL
    let authorName: String
    let createdAt: Date
    let expireAt: Date
}
```

### DTO (mirrors API shape exactly)

```swift
struct StoryDTO: Codable {
    let photoID: Int
    let photoURL: String
    let profilePicURL: String
    let authorName: String
    let createdAt: Int   // Unix timestamp
    let expireAt: Int    // Unix timestamp
}
```

### UIModel (flat display struct, ViewModel → View)

```swift
struct StoryUIModel {
    let id: Int
    let photoURL: URL
    let avatarURL: URL
    let authorName: String
    let timeAgo: String   // e.g. "10 min ago" — formatted by ViewModel
}
```

### Mapper

```swift
struct StoryMapper {
    static func toDomain(_ dto: StoryDTO) -> Story? {
        guard
            let photoURL = URL(string: dto.photoURL),
            let avatarURL = URL(string: dto.profilePicURL)
        else { return nil }
        return Story(
            id: dto.photoID,
            photoURL: photoURL,
            profilePicURL: avatarURL,
            authorName: dto.authorName,
            createdAt: Date(timeIntervalSince1970: TimeInterval(dto.createdAt)),
            expireAt: Date(timeIntervalSince1970: TimeInterval(dto.expireAt))
        )
    }
}
```

---

## Architecture

```
Presentation
  StoryViewController
    ├── UIImageView × 3 (recycled, rearranged on swipe)
    ├── UISwipeGestureRecognizer
    ├── auto-advance Timer (started post-download)
    └── owns StoryViewModel

  StoryViewModel (@MainActor)
    ├── @Published var currentStory: StoryUIModel?
    ├── @Published var isLoading: Bool
    ├── @Published var errorMessage: String?
    ├── calls FetchStoriesUseCase
    ├── calls StoryOrderService.markAsSeen(id:)
    └── calls PrefetchStoryImageUseCase.execute(url:) for nextStory

Domain
  FetchStoriesUseCase
    └── execute(policy: FetchPolicy, param: FetchStoriesParam) async throws -> [Story]

  PrefetchStoryImageUseCase
    └── execute(url: URL) → StoryRepositoryProtocol.prefetchImage(url:) → StoryImageDataSource

  StoryOrderService  ← Domain Service (stateful)
    ├── func ordered(stories: [Story]) -> [Story]  // unseen-first, then recency
    ├── func markAsSeen(id: Story.ID)
    └── func next(in stories: [Story]) -> Story?

  Story              ← Domain Model
  FetchStoriesParam  ← Param (cursor: Int?)

Data
  StoryRepository
    ├── implements StoryRepositoryProtocol
    ├── FetchPolicy.cached → local if < 10 min old, else remote
    ├── filters expired stories (expireAt < now) before returning
    ├── maps StoryDTO → Story via StoryMapper
    └── prefetchImage(url:) → StoryImageDataSource.prefetch(url:)

  StoryRemoteDataSource
    └── GET /stories?after={cursor} → [StoryDTO]

  StoryLocalDataSource
    └── read/write [StoryDTO] to disk (CoreData or Codable JSON)

  StoryImageDataSource  ← DataSource (wraps SDWebImage)
    ├── func load(url: URL, into: UIImageView, completion: @escaping () -> Void)
    └── func prefetch(url: URL)

  StoryDTO    ← DTO
  StoryMapper ← Mapper

Infrastructure
  None

External
  SDWebImage
  CoreData / JSON
  URLSession

Application
  StoryCoordinator
    ├── composition root — builds full dependency graph via manual init injection
    └── No default concrete args on `StoryRepository` init — `StoryRemoteDataSource`, `StoryLocalDataSource`, and `StoryImageDataSource` are all injected explicitly by `StoryCoordinator`.
```

**Dependency rule:** `StoryViewController` → `StoryViewModel` → `FetchStoriesUseCase` / `PrefetchStoryImageUseCase` → `StoryRepositoryProtocol` ← `StoryRepository` → `StoryRemoteDataSource` + `StoryLocalDataSource` + `StoryImageDataSource`. Domain depends on nothing.

---

## Data Flow

### Initial load

```
StoryViewController.viewDidLoad()
  → StoryViewModel.load()
      → isLoading = true
      → FetchStoriesUseCase.execute(policy: .cached, param: FetchStoriesParam(cursor: nil))
          → StoryRepository.fetch(policy: .cached, param:)
              → StoryLocalDataSource.read() → [StoryDTO]? → StoryMapper → [Story] (fast return if < 10 min old)
              → if stale: StoryRemoteDataSource.getStoriesAfter(cursor: nil) → [StoryDTO]
                          → filter expireAt < now
                          → StoryMapper.toDomain() → [Story]
                          → StoryLocalDataSource.write([StoryDTO])
          → returns [Story]
      → StoryOrderService.ordered(stories:) → sorted [Story] (unseen-first, recency)
      → ViewModel maps Story → StoryUIModel
      → @Published currentStory updated → ViewController renders
      → PrefetchStoryImageUseCase.execute(url: nextStory.photoURL)  // ViewModel → UseCase → StoryRepository → StoryImageDataSource
      → defer: isLoading = false
```

### Delta update (foreground re-entry)

```
App returns to foreground → applicationDidBecomeActive
  → StoryViewModel.refresh()
      → FetchStoriesUseCase.execute(policy: .cached, param: FetchStoriesParam(cursor: latestKnownID))
          → StoryRepository checks local timestamp
              → < 10 min old: return cached [Story] (FetchPolicy.cached satisfied)
              → ≥ 10 min old: StoryRemoteDataSource.getStoriesAfter(cursor: latestKnownID)
                              → [StoryDTO] (deltas only)
                              → filter expired
                              → merge with existing local store
                              → StoryLocalDataSource.write(merged DTOs)
          → returns merged [Story]
      → StoryOrderService.ordered(stories:) → new sort order (new unseen stories bubble to front)
      → @Published currentStory updated
```

### Timeline example

```
First session (8:00–9:00):
  cursor = nil → server returns stories 0, 1, 2, 3
  latestKnownID = 3

Foreground re-entry (12:00):
  cursor = 3 → server returns stories 4, 5, 6, 7, 8, 9 (deltas only)
  StoryOrderService places new stories at front (unseen, most recent first)
```

### Swipe gesture → image display

```
User swipes right
  → StoryViewController.didSwipe()
      → rearranges UIImageViews (3 → pos 2, 1 → pos 3)
      → ViewModel.advanceToNext()
          → StoryOrderService.markAsSeen(id: currentStory.id)
          → currentStory = StoryOrderService.next(in: stories)
          → UseCase → StoryRepository → StoryImageDataSource.load(url:, into: centreImageView) {
                completion signals download done
            }
          → @Published currentStory updated
      → ViewController reads currentStory.photoURL, triggers timer start after download completes
  → PrefetchStoryImageUseCase → StoryRepository → StoryImageDataSource.prefetch(url: nextStory.photoURL)
```

---

## Technical Deep Dives

### Three-UIImageView Carousel (View Recycling)

Three `UIImageView` instances are laid out side by side in a `UIViewController`. On each swipe, **no new views are allocated** — the existing views are repositioned:

```
Before swipe →:  [ story N-1 | story N  | story N+1 ]  (story N on screen)
After  swipe →:  [ story N   | story N+1| story N+2 ]  (story N+1 on screen)
```

The leftmost view is moved to the rightmost position (or vice versa), and its image is swapped at rest. This gives `O(1)` layout work per swipe regardless of total story count.

**Why not UICollectionView?** `UICollectionViewFlowLayout` snap-scrolling makes seamless wrap-around (story N → story 0) awkward — you'd need to insert a fake item or hack the content offset. Manual recycling handles the loop trivially.

**Why not UIPageViewController?** Same wrap-around problem, plus `UIPageViewController` instantiates new child view controllers per page — higher memory overhead for an infinite loop.

### SDWebImage as `StoryImageDataSource`

```
NSURLCache stores: raw HTTP response bytes
  → every display requires: bytes → Data → UIImage (CPU decode on main thread risk)

SDWebImage stores: decoded UIImage object directly
  → every display: cache hit returns UIImage immediately
  → download: background thread, calls back on main thread
```

`StoryImageDataSource` wraps all SDWebImage calls behind `ImageDataSourceProtocol`. The ViewModel and ViewController never import SDWebImage.

### Auto-Advance Timer

```swift
// ❌ Wrong — timer starts on transition, user sees spinner during their window
func showNext() {
    startAutoAdvanceTimer()
    imageView.sd_setImage(with: url)
}

// ✓ Correct — timer starts only after image is ready
func showNext() {
    storyImageDataSource.load(url: url, into: imageView) { [weak self] in
        self?.startAutoAdvanceTimer()
    }
}
```

### Story Expiry Enforcement

`StoryRepository` filters `expireAt < Date()` before returning Domain models. This runs on every cache read, ensuring a story fetched 23 hours ago is not displayed if it has since expired. No separate background timer needed.

### 10-Minute Throttle Guard

`StoryRepository` records the timestamp of the last successful fetch in `StoryLocalDataSource`. When `FetchPolicy.cached` is applied:
- If `now - lastFetchedAt < 10 min` → return local data, skip network
- If `now - lastFetchedAt ≥ 10 min` → call `StoryRemoteDataSource`

This is implemented entirely at the Repository level. The ViewModel always uses `FetchPolicy.cached` on foreground re-entry — it never makes the time decision itself.

**FetchPolicy travel rule:** `FetchPolicy` travels ViewModel → UseCase → Repository. Repository is the only interpreter. The 10-minute check is a custom interpretation of `.cached` at the Repository level — the ViewModel passes `.cached` and the Repository decides whether the threshold is met.

### Pre-fetching

`StoryViewModel` calls `PrefetchStoryImageUseCase.execute(url: nextStory.photoURL)` immediately after rendering the current story. The UseCase delegates to `StoryRepository.prefetchImage(url:)` → `StoryImageDataSource.prefetch(url:)`. By the time the user swipes, the next image is already decoded in SDWebImage's memory cache — zero visible latency. ViewModel never calls the DataSource directly (no Presentation → Data bypass).

### Viewed-State and Delta Merge

`StoryOrderService` holds a `Set<Story.ID>` of seen story IDs in memory. When deltas arrive:
1. New stories are added to the pool
2. `ordered(stories:)` is called on the full merged pool
3. Stories with IDs in the seen set are sorted to the back
4. `next(in:)` returns the first unseen story

**Open question from source material:** Whether the seen-set is persisted to disk (CoreData/JSON) or is memory-only. If memory-only, the user re-sees all stories on next app launch.

---

## Common Pitfalls

- **Starting auto-advance timer on transition** — burns the user's 10-second window on a loading spinner.
- **Using NSURLCache for images** — re-decodes bytes → UIImage on every cache hit; causes frame drops under fast swiping.
- **Polling on every `viewWillAppear`** — without the 10-minute guard, every tab switch hits the backend.
- **Allocating new UIImageViews per swipe** — triggers layout passes; always reuse the three existing views.
- **Not cancelling in-flight prefetch on backward swipe** — prefetch for story N+1 should be cancelled if the user swipes to N-1.
- **Not filtering `expireAt` on cache read** — a story cached hours ago may have expired before display.
- **Forgetting to carry viewed-state through delta merge** — if `StoryOrderService` doesn't preserve the seen set, previously-viewed stories reappear at the front after a refresh.

---

## Key Takeaways

I'd design a Story Viewer with a single `getStoriesAfter(cursor:)` endpoint — stories are 24-hour bounded, the full metadata response is ~50 KB, and a single cursor covers both initial load and delta updates. The 10-minute throttle guard lives entirely in `StoryRepository` via `FetchPolicy.cached` — the ViewModel never makes that decision. For the UI, three recycled `UIImageView` instances with a swipe gesture recognizer give seamless infinite loop that UICollectionView and UIPageViewController can't easily provide. Image performance comes from `StoryImageDataSource` (SDWebImage — stores decoded `UIImage`, background download) and pre-fetching the next image on every display cycle. `StoryOrderService` is a stateful Domain Service — not a UseCase — because it holds the viewed-state `Set<ID>` across swipes and foreground re-entries. The auto-advance timer starts only after SDWebImage signals download completion, guaranteeing a full 10 seconds of visible content.
