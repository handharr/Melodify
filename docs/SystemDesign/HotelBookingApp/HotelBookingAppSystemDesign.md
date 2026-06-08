# iOS Hotel Booking App — System Design

**Source:** Mock interview study notes — Senior iOS Engineer level, ~10M DAU scale.

> Scenario extension of [`docs/ios-app-system-design-philosophy.md`](../ios-app-system-design-philosophy.md)
> Read the delta below first.

---

## Delta — What This Scenario Adds

### Same as generic architecture

- Clean Architecture + MVVM + UIKit (plus SwiftUI for some screens — see delta)
- DTO → Mapper → Domain Model
- `FetchPolicy` (.fresh / .cached / .strict) on all Repository reads
- Typed `Param` structs on every UseCase
- `@MainActor` on ViewModel — all state mutations on main thread, no `DispatchQueue.main.async`
- `defer { isLoading = false }` — guaranteed cleanup on success and failure
- `[weak self]` in all closures to avoid retain cycles
- Coordinator-based navigation; app-scoped services registered at AppCoordinator level
- Mock-the-layer-below testing strategy
- `async/await` for I/O; Combine for reactive binding to `@Published` state
- Idempotency keys on mutations — client-generated UUID at `Param` call site for any retryable mutation
- HTTP 409 ≠ 5xx — concurrency conflicts and transient server errors must never share a code path

### What this scenario adds

| Concept | Generic | This Scenario |
|---|---|---|
| Image storage | Not in generic | Two-tier cache: `ImageDiskDataSource` (disk) + CoreData metadata index (`url → filePath + savedAt` for TTL) |
| Offline storage | Not in generic | `ReservationLocalDataSource` (CoreData) — read-only offline reservation history |
| Domain Services | `Service` suffix — stateful/long-lived, no SDK imports | `ReservationService` (hold timer + live state) · `ImageService` (two-tier cache) · `PaymentService` (orchestrates payment flow via `PaymentGatewayProtocol`) |
| Infrastructure / SDK facade | Gateway in Infrastructure for cross-layer SDKs | `StripePaymentGateway: PaymentGatewayProtocol` — only class that imports Stripe SDK; `PaymentService` (Domain) injects protocol, never the SDK |
| Hold timer | Not in generic | Server-authoritative 15-min lock; client counts down using server's `expiration_time` |
| Idempotency key | UUID at `Param` call site for retryable mutations | Client-generated `local_id` UUID — prevents duplicate reservations/charges on network retry |
| Pagination | Not in generic | Offset-limit — simpler; BE controls sort order; data doesn't move mid-scroll |
| Autocomplete strategy | Not in generic | Local prefetch on launch + debounced HTTP GET fallback — WebSockets explicitly rejected |
| Amenity library | Not in generic | Batch-fetched on launch via `FetchAmenitiesUseCase`; `amenity_id` matched locally — no per-hotel icon network calls |
| UI framework split | SwiftUI default; UIKit when scroll lifecycle or custom transitions needed | UIKit `UITableView` for Hotel List (scroll + pagination lifecycle control); SwiftUI for Search, Detail, Reservation, Payment |
| DI framework | Manual init injection | Swinject — manages graph complexity; singleton vs transient scoping enforced per service |
| Conflict handling | 409 ≠ 5xx (see generic doc) | HTTP 409 Conflict → distinct "room no longer available" UX + redirect to Hotel Detail (separate path from 5xx/timeout retry UI) |

### Key decisions unique to this scenario

- **`ReservationService` must be app-scoped.** It owns the live 15-min countdown timer. If owned by a ViewModel, it deallocates when the screen pops — the hold state is lost.
- **Server owns the clock.** `expiration_time` is always server-generated. Client never calculates a hold window — it only displays a countdown.
- **Offset-limit over cursor pagination.** BE controls sort order; results don't change mid-scroll (no cross-device sync like music library). Offset is simpler and sufficient.
- **WebSockets rejected twice.** For autocomplete and for the hold timer — HTTP + client countdown achieves the same UX at a fraction of the cost at 10M DAU.
- **Image cache and offline reservation storage are separate.** Cache pressure must not evict user reservation data. `ImageDiskDataSource` for images and `ReservationLocalDataSource` for reservations never share storage.
- **`local_id` is always client-generated.** Standard industry idempotency key. Prevents duplicate charges on network retry. Server dedup would add server complexity; client UUID is cheap and reliable.

---

## Requirements

### Functional

- Search hotels by destination, check-in/out dates, guest count
- Autocomplete for destination input (local-first, debounced HTTP GET fallback)
- Hotel list with name, location, price, rating (sorting owned by BE)
- Hotel detail: image gallery (thumbnails + full-size), amenities (icon + label), available rooms
- Reserve one or multiple rooms → 15-minute hold timer
- Payment via third-party SDK (Stripe) — app never handles raw card data
- View existing reservation details offline (read-only)

### Non-Functional

- ~10M DAU — design for high-scale read traffic
- No raw financial data stored on client
- Offline: cached images + reservation history readable without network

---

## Screen Inventory

| Screen | Key UI | Framework |
|---|---|---|
| Search | Destination, dates, guest count, autocomplete dropdown | SwiftUI |
| Hotel List | Paginated cards (name, location, price, rating) | UIKit (`UITableView`) |
| Hotel Detail | Image gallery, amenities, room list, Reserve CTA | SwiftUI |
| Reservation | Room summary, 15-min countdown timer, Proceed to Payment | SwiftUI |
| Payment | Name, credit card (Stripe SDK UI), billing address | SwiftUI |

**Why UIKit for Hotel List only:** `UITableView` / `UICollectionView` give granular scroll position control and reliable pagination lifecycle hooks. SwiftUI `List` lacks the lifecycle hooks needed to reliably trigger the next-page fetch at 10M-scale result sets.

---

## API Design

### Endpoints

| Method | Route | Purpose |
|--------|-------|---------|
| `GET` | `/hotels` | Search + paginated hotel list |
| `GET` | `/hotels/:hotel_id` | Hotel detail |
| `GET` | `/amenities` | Full amenity library (batch fetch, called on app launch) |
| `POST` | `/reservations` | Create reservation (places hold) |
| `POST` | `/reservations/payment` | Finalize payment |

### GET /hotels — Query Params

```
destination=<string>
check_in=<string>
check_out=<string>
guest_count=<int>
offset=<int>
limit=<int>          // 25 per page
```

### POST /reservations — Request Body

```
CreateReservationRequest {
  local_id: String       // client-generated UUID — idempotency key
  hotel_id: String
  room_id: [String]      // supports multi-room booking
  guest_count: Int
}
```

### POST /reservations — Response

```
ReservationDTO {
  reservation_id: String
  expiration_time: String    // server-authoritative 15-min timestamp
  ...
}
```

### POST /reservations/payment — Request Body

```
PaymentRequest {
  payment_token: String    // token from Stripe SDK — not raw card data
}
```

**Key decisions:**
- `local_id` is a client-generated UUID — standard idempotency key; prevents duplicate reservations/charges on network retry
- `expiration_time` is server-generated — client never owns the clock for the hold
- Pagination is offset-limit — simpler; BE controls sort order and the result set doesn't shift mid-scroll

---

## Data Model

### DTOs (Data layer — mirror API shape exactly)

```swift
struct HotelListingsDTO: Codable {
    let offset: Int
    let hotelListings: [HotelListingDTO]
}

struct HotelListingDTO: Codable {
    let hotelId: String
    let location: String
    let price: Decimal
    let rating: String
    let mediaUrl: String        // single thumbnail for list card
}

struct HotelDTO: Codable {
    let hotelId: String
    let amenities: [AmenityDTO]
    let rooms: [RoomDTO]
    let mediaUrls: MediaUrlsDTO
}

struct MediaUrlsDTO: Codable {
    let thumbnails: [String]
    let fullSizeImages: [String]
}

struct AmenityDTO: Codable {
    let amenityId: String
    let amenityDescription: String
    let iconUrl: String
}

struct RoomDTO: Codable {
    let roomId: String
    let numberOfBeds: Int
    let mediaUrl: String
}

struct ReservationDTO: Codable {
    let reservationId: String
    let expirationTime: String
}

struct OfflineReservationDTO {   // CoreData entity — for offline read
    let reservationId: String
    let expirationTime: String
    let hotelName: String
    let checkIn: String
    let checkOut: String
}
```

### Domain Models (Domain layer — pure Swift, no UIKit/networking imports)

```swift
struct HotelListing {
    let hotelId: String
    let location: String
    let price: Decimal
    let rating: String
    let thumbnailUrl: URL
}

struct Hotel {
    let hotelId: String
    let amenities: [Amenity]
    let rooms: [Room]
    let thumbnailUrls: [URL]
    let fullSizeImageUrls: [URL]
}

struct Amenity {
    let amenityId: String
    let description: String
    let iconUrl: URL
}

struct Room {
    let roomId: String
    let numberOfBeds: Int
    let thumbnailUrl: URL
}

struct Reservation {
    let reservationId: String
    let expirationTime: Date       // server-authoritative
    let hotelName: String
    let checkIn: Date
    let checkOut: Date
}
```

> **Amenity icons are standardized across the hotel chain.** Fetched via `/amenities` on app launch (batch), stored in `AmenityLocalDataSource`. When a `Hotel` detail arrives, the app matches `amenityId` against the local library — no per-hotel icon network calls. Keeps hotel detail payloads lightweight.

---

## Architecture

### Presentation (UIKit · SwiftUI · Combine)

```
SearchViewController + SearchViewModel (SwiftUI)
HotelListViewController + HotelListViewModel (UIKit UITableView)
HotelDetailViewController + HotelDetailViewModel (SwiftUI)
ReservationListViewController + ReservationListViewModel (SwiftUI)
ReservationViewController + ReservationViewModel (SwiftUI)
PaymentViewController + PaymentViewModel (SwiftUI)
```

All ViewModels: `@MainActor`, `@Published` state, map Domain → UIModel before publishing.

### Domain

**UseCases**
```
SearchHotelsUseCase
FetchHotelDetailUseCase
FetchAmenitiesUseCase
FetchReservationsUseCase
CreateReservationUseCase
ProcessPaymentUseCase
```

**Services**
```
ReservationService   — hold timer + live state (app-scoped singleton)
ImageService         — two-tier image cache; calls ImageRepositoryProtocol (no SDK imports)
PaymentService       — orchestrates payment flow via PaymentGatewayProtocol (no SDK imports)
```

**Models**
```
HotelListing · Hotel · Amenity · Room · Reservation
```

**Params**
```
SearchHotelsParam
FetchHotelDetailParam(hotelId:)
FetchAmenitiesParam
FetchReservationsParam
CreateReservationParam(localId: UUID, hotelId:, roomIds:, guestCount:)
ProcessPaymentParam(token:)
```

### Data

**Repositories**
```
HotelRepository
ReservationRepository
AmenityRepository
ImageRepository
PaymentRepository
```

**DataSources**
```
HotelRemoteDataSource
HotelLocalDataSource          — prefix search cache (searchPrefix) + hotel detail cache
AmenityRemoteDataSource
AmenityLocalDataSource        — amenity library (batch-fetched on launch)
ReservationRemoteDataSource
ReservationLocalDataSource    — CoreData, offline reservation history (read-only)
MediaRemoteDataSource         — S3 image fetch
ImageLocalDataSource          — CoreData metadata index: url, filePath, savedAt, TTL
                                (stores file path + TTL metadata only — no binary blobs)
ImageDiskDataSource           — disk binary files (thumbnails + full-size)
                                (distinct from ImageLocalDataSource: disk holds binaries,
                                 CoreData holds the metadata index)
PaymentRemoteDataSource
```

**DTOs**
```
HotelListingsDTO · HotelListingDTO · HotelDTO · MediaUrlsDTO
AmenityDTO · RoomDTO · ReservationDTO · OfflineReservationDTO
```

**Mappers**
```
HotelListingMapper · HotelMapper · AmenityMapper · RoomMapper · ReservationMapper
```

### Application

```
AppDelegate
AppCoordinator (root — registers app-scoped singletons, handles deep links)
SearchCoordinator · HotelListCoordinator · ReservationCoordinator · PaymentCoordinator
Swinject DI container
```

### Infrastructure

```
StripePaymentGateway: PaymentGatewayProtocol
  — only class that imports the Stripe SDK
  — wired by Application (AppCoordinator.setupDependencies())
  — never imported by Domain, Data, or Presentation
```

### External

```
Stripe · CoreData · Foundation (FileManager) · URLSession
```

---

### Swinject Scoping

| Scope | Service | Reason |
|---|---|---|
| Singleton | `ReservationService` | Owns live hold state + 15-min countdown timer across screens |
| Singleton | `ImageService` | Owns two-tier image cache — must persist across screens |
| Singleton | `PaymentService` | Orchestrates payment flow via `PaymentGatewayProtocol` — one instance |
| Transient | UseCases | Stateless — no mutable state to share |

**Rule of thumb:** if a service owns mutable state that must stay consistent across ViewModels, it must be a singleton.

> **Registration site:** `ReservationService`, `ImageService`, and `PaymentService` are registered as singletons in `AppCoordinator.setupDependencies()` — not in any ViewModel or feature coordinator.

---

### Combine + async/await Split

```
RemoteDataSource / LocalDataSource
  └── async/await (I/O boundary)
          │
          ▼
      Repository (coordinates DataSources, applies FetchPolicy)
          │
          ▼
      UseCase / Domain Service
          │
          ▼
      ViewModel (@Published) — drives SwiftUI / UIKit view
```

`async/await` handles the I/O layer. Combine handles the reactive binding layer (ViewModel → View via `@Published`). Domain Services expose `AnyPublisher` for state the ViewModel needs to observe long-term (e.g. hold timer countdown).

---

## Data Flow

### Search + Hotel List

Pattern A — two awaits in the ViewModel. `async/await` returns once; a single `execute()` cannot update state twice.

```
SearchViewModel.search(param:)
    → isLoading = true

    // Phase 1 — cache (instant)
    if let cached = try? await SearchHotelsUseCase.execute(policy: .strict, param:)
        → HotelRepository checks HotelLocalDataSource only — throws on miss
        → ViewModel maps [HotelListing] → UIModel
        → @Published update → view renders immediately from cache

    // Phase 2 — network (background)
    let fresh = try await SearchHotelsUseCase.execute(policy: .fresh, param:)
        → HotelRepository fetches HotelRemoteDataSource.get("/hotels", query:)
        → HotelListingsDTO → Mapper → [HotelListing]
        → HotelLocalDataSource.save(dtos)
        → ViewModel maps [HotelListing] → UIModel
        → @Published update → view refreshes with latest

    → defer: isLoading = false
```

> **Pattern A vs Pattern B:** Pattern B (AsyncStream) was considered; Pattern A retained — the two-phase load is not shared enough across ViewModels to justify stream mocking complexity.

### Hotel Detail

Pattern A — two awaits in the ViewModel.

```
HotelDetailViewModel.load(hotelId:)
    → isLoading = true

    // Phase 1 — cache (instant)
    if let cached = try? await FetchHotelDetailUseCase.execute(policy: .strict, param:)
        → HotelRepository checks HotelLocalDataSource only — throws on miss
        → ImageService.loadImage(url:) for cached gallery thumbnails
        → ViewModel maps Hotel + resolved images → UIModel
        → @Published update → view renders immediately from cache

    // Phase 2 — network (background)
    let fresh = try await FetchHotelDetailUseCase.execute(policy: .fresh, param:)
        → HotelRepository fetches HotelRemoteDataSource.get("/hotels/:id")
        → HotelDTO → Mapper → Hotel
        → HotelLocalDataSource.save(dto)
        → ImageService.loadImage(url:) for updated gallery
          // Thumbnail images loaded concurrently via `withThrowingTaskGroup` inside `ImageService` — dynamic count of image URLs.
        → ViewModel maps Hotel + resolved images → UIModel
        → @Published update → view refreshes

    → defer: isLoading = false
```

### Create Reservation

```
ReservationViewModel.reserve(param:)
  → CreateReservationUseCase.execute(param:)   // param.localId = UUID()
      → ReservationRepository
          1. ReservationRemoteDataSource.post("/reservations", body:) → ReservationDTO → Mapper → Reservation
          2. ReservationLocalDataSource.save(dto)  // write offline record immediately, before navigating
      → returns Reservation
  → ReservationService.startHold(reservation:)  // begins 15-min countdown using server's expiration_time
  → Coordinator pushes PaymentViewController with reservation.reservationId injected via init
```

### Payment

```
PaymentViewModel.pay()
  → PaymentService [Domain Service — app-scoped singleton]
      1. paymentGateway.collectToken()   // StripePaymentGateway (Infrastructure) — presents Stripe UI, returns token
      2. → ProcessPaymentUseCase.execute(param: PaymentParam(token:))
             → PaymentRepository (PaymentRepositoryProtocol)
                 → PaymentRemoteDataSource.post("/reservations/payment", body: { payment_token })
      → returns success
  → Coordinator navigates to confirmation screen
```

### Autocomplete

Debounce lives in the ViewModel — only the final keystroke after 300ms silence triggers a lookup.

```
SearchViewModel — on each keystroke (debounced 300ms)

    // Phase 1 — local prefix search (zero latency)
    let local = HotelLocalDataSource.searchPrefix(query:)
    if !local.isEmpty
        → ViewModel maps results → UIModel
        → @Published update → autocomplete dropdown renders immediately

    // Phase 2 — remote fallback (on cache miss only)
    if local.isEmpty
        let remote = try await SearchHotelsUseCase.execute(policy: .fresh, param: SearchHotelsParam(destination: query))
            → HotelRepository → HotelRemoteDataSource.get("/hotels?destination=<query>")
            → HotelListingsDTO → Mapper → [HotelListing]
            → HotelLocalDataSource.save(results)   // cache for future keystrokes
        → ViewModel maps [HotelListing] → UIModel
        → @Published update → dropdown refreshes
```

> **Why debounce in the ViewModel:** the ViewModel owns all user interaction timing. Putting debounce in the UseCase or Repository would force every caller to match autocomplete's timing contract — wrong layer.

### Offline Reservation Read

```
ReservationListViewModel.loadReservations()
    → isLoading = true
    → FetchReservationsUseCase.execute(policy: .strict, param:)
        → ReservationRepository(.strict) → ReservationLocalDataSource only — throws if empty
        → [OfflineReservationDTO] → ReservationMapper → [Reservation]
    → ViewModel maps [Reservation] → UIModel
    → @Published update → view renders reservation history
    → defer: isLoading = false
```

> **FetchPolicy .strict as primary policy:** every other flow in this scenario uses `.strict` as a Phase 1 cache probe before falling back to `.fresh`. Offline read is the only flow where `.strict` is the sole policy — a missing local record is a hard miss, not a fallback trigger. No network call is ever attempted.

### Amenity Prefetch on Launch

```
AppCoordinator.start()
    → FetchAmenitiesUseCase.execute(param: FetchAmenitiesParam())
        → AmenityRepository
            → AmenityRemoteDataSource.get("/amenities") → [AmenityDTO] → AmenityMapper → [Amenity]
            → AmenityLocalDataSource.save(dtos)
    // amenity library now ready for local matching

// Later — HotelDetailViewModel.load(hotelId:)
    → HotelDTO arrives with amenities: [AmenityDTO] (id + description only — no icon URL in hotel payload)
    → HotelMapper resolves each amenityId against AmenityLocalDataSource.find(amenityId:)
    → full Amenity (id + description + iconUrl) assembled locally
    // zero per-hotel icon network calls
```

---

## Trade-off Summary

| Decision | Chosen | Rejected | Why |
|----------|--------|---------|-----|
| Autocomplete | Prefetch + debounced HTTP GET | WebSocket streaming | Too expensive at 10M DAU |
| Reservation hold timer | Server timestamp + client countdown | WebSockets / long-poll | Simpler; server stays authoritative |
| Image caching | Manual `ImageDiskDataSource` + CoreData TTL/LRU | URLSession default cache | Granular eviction control |
| Payment | Stripe SDK token | DIY card collection | PCI compliance; no raw card data on client |
| Pagination | Offset-limit | Cursor-based | Simpler; BE owns sort order; data doesn't move mid-scroll |
| Idempotency | Client-generated `local_id` UUID | Server dedup | Handles network retry duplicates cheaply |
| DI | Swinject | Manual init injection | Manages graph complexity at scale |
| Hotel List UI | UIKit `UITableView` | SwiftUI `List` | Granular scroll + pagination lifecycle control |

---

## 6. Technical Deep-dive

### Why two-tier image cache instead of URLSession default?

Gallery images (thumbnails + full-size) are numerous and frequently accessed. URLSession's default cache is not granular enough for TTL eviction or LRU size capping.

```
Image Request (via ImageService)
     │
     ▼
ImageRepository.loadImage(url:)   // ImageRepositoryProtocol — Domain Service never calls DataSources directly
     │
     ▼
ImageDiskDataSource (disk)
     │ hit? → serve immediately
     │ miss?
     ▼
MediaRemoteDataSource (S3 fetch)
     │
     ▼
Write binary file to disk (ImageDiskDataSource)
Write metadata record to CoreData (ImageLocalDataSource):
  { url: String, filePath: String, savedAt: Date }
```

> **FetchPolicy exception:** FetchPolicy does not apply to `ImageRepository` — the two-tier cache decision (disk-hit vs remote fetch) is encapsulated inside `ImageRepository` itself and is not ViewModel-driven.

**TTL eviction:** Runs on `DispatchQueue.global(qos: .background)` — triggered on app launch or on a periodic interval while the app is active. Queries CoreData for `savedAt < now - TTL`, deletes matching files and records. Never touches the main thread.

> `BGTaskScheduler` was considered for eviction when the app is suspended, but `DispatchQueue.global` is sufficient and significantly simpler.

**LRU size cap:** Alongside TTL, a size threshold prevents disk bloat. When the cap is hit, oldest entries are pruned first (LRU-style) regardless of TTL. Thumbnails and full-size images are cached independently — both sizes available for their respective UIs without re-fetching.

---

### Why CoreData as metadata index for image cache (not binary blob store)?

Binary blobs in CoreData bloat the persistent store. `ImageLocalDataSource` stores only `{ url, filePath, savedAt }` as a lightweight index. `ImageDiskDataSource` holds the actual binary files on disk. This keeps the CoreData store lean and fast while still enabling TTL queries and LRU eviction without loading image data into memory.

---

### Why offline storage is limited to read-only reservation history?

CoreData entity written immediately after a successful `POST /reservations` response, before navigating to Payment:

```swift
struct OfflineReservationDTO {
    let reservationId: String
    let expirationTime: String
    let hotelName: String
    let checkIn: String
    let checkOut: String
}
```

Creating a reservation always requires a live server lock — the hold timer is server-authoritative. No offline creation, no sync flow. `ReservationLocalDataSource` and `ImageDiskDataSource` never share storage — cache pressure must not evict user booking data.

---

### Why local prefetch + debounced GET for autocomplete instead of WebSockets?

Real-time character-by-character fetching at 10M DAU is prohibitively expensive. Open persistent WebSocket connections at that scale add massive server-side cost for marginal UX benefit.

```
User types
     │
     ▼
HotelLocalDataSource (searchPrefix)
(prefetched popular destinations + hotel names on launch)
     │ hit? → show immediately (zero latency)
     │ miss?
     ▼
HotelRemoteDataSource.get("/hotels?destination=<substring>")
(debounced — does not fire on every keystroke)
     │
     ▼
Display results + cache response locally
```

**Prefetch on launch:** Popular locations and high-traffic hotel names are fetched once at app start and stored via `HotelLocalDataSource`. Covers the majority of queries for free.

---

### Why server-authoritative hold timer instead of WebSockets or long-polling?

Two users booking the same room simultaneously requires a 15-minute payment window enforced by the server.

```
Client: CreateReservationUseCase → POST /reservations
     │
     ▼
Server: Lock room_id + hotel_id
Server: Generate expiration_time (now + 15 min)
     │
     ▼
Client: Receive reservation_id + expiration_time
Client: ReservationService.startHold(reservation:)
        → starts local countdown using server's expiration_time
     │
     ├── Payment completed before expiry → POST /reservations/payment ✓
     │
     └── Timer expires / concurrency conflict
              │
              ▼
         HTTP 409 Conflict → "room no longer available" UX → redirect to Hotel Detail
         HTTP 5xx / timeout → generic network error UX
         (Two distinct error paths — never conflate them)
```

Client timer is cosmetic only — the server clock is authoritative. WebSockets, long-polling, and server-sent events are all rejected: server timestamp + client countdown is sufficient and far simpler at 10M DAU.

---

### Why StripePaymentGateway in Infrastructure instead of a DataSource?

Stripe spans two layers: Presentation (card collection UI) and Data (token API call). Neither layer alone is the right home for it — the Gateway trigger is cross-layer span, not the presence of a third-party import.

```
User enters card details → Stripe SDK UI
     │
     ▼
Stripe SDK returns payment_token
     │
     ▼
PaymentService → ProcessPaymentUseCase
     → POST /reservations/payment { payment_token }
     │
     ▼
BE charges card server-side via Stripe API
```

`PaymentService` (Domain Service) calls `PaymentGatewayProtocol.collectToken()` — it never imports the Stripe SDK. `StripePaymentGateway` is the only file that imports Stripe. Swapping payment providers = one file in Infrastructure, nothing else.

> **Why `PaymentService` delegates to `ProcessPaymentUseCase`:** `PaymentService` orchestrates the two-step flow — it acquires the token via `PaymentGatewayProtocol`, then delegates the network call to `ProcessPaymentUseCase` to keep Repository/DataSource independently testable from token acquisition.

---

### Why offset-limit pagination instead of cursor-based?

Hotel search results don't shift mid-scroll — there is no cross-device sync that would insert new items into a page boundary. BE controls sort order. Offset is simpler and sufficient; cursor pagination adds complexity without benefit here.

---

### Why Swinject over manual init injection?

`ReservationService`, `ImageService`, and `PaymentService` all require singleton scoping enforced across multiple coordinators. Manual init injection at this graph complexity becomes error-prone — passing the same singleton instance through every coordinator init is fragile. Swinject enforces the scoping contract at registration time.

### Why UIKit for Hotel List instead of SwiftUI?

`UITableView`/`UICollectionView` expose granular `willDisplay cell` lifecycle hooks needed to reliably trigger the next-page fetch at 10M-scale result sets. SwiftUI `List` does not provide equivalent lifecycle control for pagination.

---

### Interview Q&A

| Question | Answer |
|---|---|
| Why not WebSockets for autocomplete? | Too expensive at 10M DAU — local prefetch + debounced GET achieves same UX |
| Who owns the hold timer clock? | Server generates `expiration_time`; client only displays countdown |
| What prevents duplicate reservations on network retry? | Client-generated `local_id` UUID — server deduplicates on match |
| Why is `ReservationService` app-scoped? | Owns live hold state + 15-min countdown; ViewModel scope would deallocate it on screen pop |
| What does HTTP 409 mean here vs 5xx? | 409 = room no longer available → distinct UX + redirect to Hotel Detail; 5xx = transient → generic retry UI |
| Why CoreData for image metadata instead of storing images in CoreData? | Binary blobs in CoreData bloat the persistent store; CoreData as metadata index (`url`, `filePath`, `savedAt`) keeps it lean while disk holds binaries |
| Why Swinject over manual injection? | Service graph complexity — `ReservationService`, `ImageService`, `PaymentService` all need singleton scoping enforced across multiple coordinators |

---

## Key Takeaways

- **Idempotency key** — always client-generated for mutation requests that could be retried
- **Server-authoritative timestamps** — never trust the client clock for business-critical windows (hold expiry)
- **Facade over third-party SDKs** — `StripePaymentGateway` (Infrastructure) wraps Stripe SDK behind `PaymentGatewayProtocol`; `PaymentService` (Domain Service) orchestrates without importing the SDK; `ImageService` wraps caching logic; rest of app calls protocols
- **Prefetch on launch** — for data expensive to fetch per-keystroke but bounded in size (autocomplete, amenity icons)
- **CoreData as metadata index, not blob store** — store file paths and TTL data; binary files live on disk
- **Domain Services must be app-scoped** — `ReservationService` owns the hold timer; if owned by a ViewModel, it deallocates when the screen pops
- **HTTP 409 ≠ 5xx** — concurrency conflicts get distinct UX; never conflate them with generic network errors

---

## Bonus — Feedback & Rating System (out of interview scope)

- `FeedbackService` triggers post-checkout (1–2 hrs after payment confirmation)
- Channels: in-app star rating (immediate) + post-stay text survey (optional, delayed)
- Each submission attaches metadata: app version, OS, ViewModel state at time of submission
- Central `POST /feedback` endpoint consolidates all sources
- Negative feedback → automated alert to support; positive → prompt for public review
- Keep surveys under 60 seconds to maximize completion rate
