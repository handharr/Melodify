# iOS Hotel Booking App — System Design

**Source:** Mock interview study notes — Senior iOS Engineer level, ~10M DAU scale.

> Scenario extension of [`docs/ios-app-system-design.md`](../ios-app-system-design.md)
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
- `ThirdPartyDataSource` (SDK facade) — wraps third-party SDKs as a `RemoteDataSource`; app calls protocol, never SDK directly
- Idempotency keys on mutations — client-generated UUID at `Param` call site for any retryable mutation
- HTTP 409 ≠ 5xx — concurrency conflicts and transient server errors must never share a code path

### What this scenario adds

| Concept | Generic | This Scenario |
|---|---|---|
| Image storage | Not in generic | Two-tier cache: `LocalFileDataSource` (disk) + CoreData metadata index (`url → filePath + savedAt` for TTL) |
| Offline storage | Not in generic | `ReservationLocalDataSource` (CoreData) — read-only offline reservation history |
| Domain Services | Generic (SessionService example) | `ReservationService` (hold timer + live state) · `ImageService` (two-tier image cache) · `PaymentService` (Stripe SDK facade) |
| Hold timer | Not in generic | Server-authoritative 15-min lock; client counts down using server's `expiration_time` |
| Idempotency key | Documented in generic — UUID at `Param` call site for retryable mutations | Client-generated `local_id` UUID on every mutation — prevents duplicate reservations/charges on network retry |
| Pagination | Not in generic | Offset-limit — simpler; BE controls sort order; data doesn't move mid-scroll (no cross-device sync) |
| Third-party SDK facade | `ThirdPartyDataSource` pattern documented in generic (wraps SDK as `RemoteDataSource`) | `PaymentService` wraps Stripe SDK — rest of app never calls SDK directly |
| Autocomplete strategy | Not in generic | Local prefetch on launch + debounced HTTP GET fallback — WebSockets explicitly rejected |
| Amenity library | Not in generic | Batch-fetched on launch via `FetchAmenitiesUseCase`; `amenity_id` matched locally — no per-hotel icon network calls |
| UI framework split | SwiftUI default for new apps; UIKit when scroll lifecycle, AVPlayer, or custom transitions needed; hybrid valid screen-by-screen | UIKit `UITableView` for Hotel List (scroll + pagination lifecycle control); SwiftUI for Search, Detail, Reservation, Payment |
| DI framework | Manual init injection | Swinject — manages graph complexity; singleton vs transient scoping enforced per service |
| Conflict handling | 409 ≠ 5xx must never share a code path (see generic doc) | HTTP 409 Conflict → distinct "room no longer available" UX + redirect to Hotel Detail (separate path from 5xx/timeout retry UI) |

### Key decisions unique to this scenario

- **`ReservationService` must be app-scoped.** It owns the live 15-min countdown timer. If owned by a ViewModel, it deallocates when the screen pops — the hold state is lost.
- **Server owns the clock.** `expiration_time` is always server-generated. Client never calculates a hold window — it only displays a countdown.
- **Offset-limit over cursor pagination.** BE controls sort order; results don't change mid-scroll (no cross-device sync like music library). Offset is simpler and sufficient.
- **WebSockets rejected twice.** For autocomplete and for the hold timer — HTTP + client countdown achieves the same UX at a fraction of the cost at 10M DAU.
- **Image cache and offline reservation storage are separate.** Cache pressure must not evict user reservation data. `LocalFileDataSource` for images and `ReservationLocalDataSource` for reservations never share storage.
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

### Layer Breakdown

| Layer | What lives here |
|---|---|
| Presentation | `ViewController` + `ViewModel` (@MainActor, @Published) · SwiftUI Views |
| Domain — UseCase | `SearchHotelsUseCase` · `FetchHotelDetailUseCase` · `FetchAmenitiesUseCase` · `CreateReservationUseCase` · `ProcessPaymentUseCase` |
| Domain — Service | `ReservationService` (hold timer + live state) · `ImageService` (two-tier cache) · `PaymentService` (presents Stripe SDK UI, collects token, delegates to `ProcessPaymentUseCase`) |
| Data — Repository | `HotelRepository` · `ReservationRepository` · `AmenityRepository` · `ImageRepository` |
| Data — DataSource | `HotelRemoteDataSource` · `HotelLocalDataSource` · `ReservationRemoteDataSource` · `ReservationLocalDataSource` · `AmenityLocalDataSource` · `MediaRemoteDataSource` · `ImageLocalDataSource` · `LocalFileDataSource` |
| Application | `AppDelegate` · `Coordinator` (per flow) · Swinject DI container |

### Swinject Scoping

| Scope | Service | Reason |
|---|---|---|
| Singleton | `ReservationService` | Owns live hold state + 15-min countdown timer across screens |
| Singleton | `ImageService` | Owns two-tier image cache — must persist across screens |
| Singleton | `PaymentService` | Presents Stripe SDK UI, collects token, orchestrates `ProcessPaymentUseCase` — one instance |
| Transient | UseCases | Stateless — no mutable state to share |

**Rule of thumb:** if a service owns mutable state that must stay consistent across ViewModels, it must be a singleton.

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

```
SearchViewModel.search(param:)
  → SearchHotelsUseCase.execute(policy: .fresh, param:)
      → HotelRepository
          1. HotelLocalDataSource.fetch() → cached HotelListingDTOs → Mapper → [HotelListing] (fast return)
          2. HotelRemoteDataSource.get("/hotels", query:) → HotelListingsDTO → Mapper → [HotelListing]
          3. HotelLocalDataSource.save(dtos)
      → returns [HotelListing]
  → ViewModel maps HotelListing → UIModel → @Published update → view re-renders
```

### Hotel Detail

```
HotelDetailViewModel.load(hotelId:)
  → FetchHotelDetailUseCase.execute(policy: .cached, param:)
      → HotelRepository
          1. HotelLocalDataSource.fetch(hotelId) → HotelDTO? → Mapper → Hotel? (fast return)
          2. HotelRemoteDataSource.get("/hotels/:id") → HotelDTO → Mapper → Hotel
          3. HotelLocalDataSource.save(dto)
      → returns Hotel
  → ImageService.loadImage(url:) for gallery thumbnails and full-size images (two-tier cache)
  → ViewModel maps Hotel + resolved images → UIModel → @Published update
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
      1. presents Stripe SDK UI → receives payment_token
      2. → ProcessPaymentUseCase.execute(param: PaymentParam(token: payment_token))
             → PaymentRepository (PaymentRepositoryProtocol)
                 → PaymentRemoteDataSource.post("/reservations/payment", body: { payment_token })
      → returns success
  → Coordinator navigates to confirmation screen
```

---

## Deep Dives

### Image Caching

**Problem:** Gallery images (thumbnails + full-size) are numerous and frequently accessed. URLSession default cache is not granular enough.

**Two-tier cache:**

```
Image Request (via ImageService)
     │
     ▼
LocalFileDataSource (disk)
     │ hit? → serve immediately
     │ miss?
     ▼
MediaRemoteDataSource (S3 fetch)
     │
     ▼
Write binary file to disk (LocalFileDataSource)
Write metadata record to CoreData (ImageLocalDataSource):
  { url: String, filePath: String, savedAt: Date }
```

**TTL eviction:** Runs on `DispatchQueue.global(qos: .background)` — triggered on app launch or on a periodic interval while the app is active. Queries CoreData for `savedAt < now - TTL`, deletes matching files and records. Never touches the main thread.

> `BGTaskScheduler` was considered for eviction when the app is suspended, but `DispatchQueue.global` is sufficient and significantly simpler.

**LRU size cap:** Alongside TTL, a size threshold prevents disk bloat. When the cap is hit, oldest entries are pruned first (LRU-style) regardless of TTL. Thumbnails and full-size images are cached independently — both sizes available for their respective UIs without re-fetching.

---

### Offline Reservation Storage

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

**Scope:** Read-only offline access — user can view existing booking details without network. Creating a reservation always requires a live server lock. No offline creation, no sync flow.

---

### Search Autocomplete

**Problem:** Real-time character-by-character fetching at 10M DAU is too expensive. WebSockets are rejected.

**Strategy — local-first:**

```
User types
     │
     ▼
AmenityLocalDataSource / search cache
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

**Prefetch on launch:** Popular locations and high-traffic hotel names are fetched once at app start and stored in a local search cache (same CoreData stack or dedicated UserDefaults payload). Covers the majority of queries for free.

**Why not WebSockets?** Open persistent connections at 10M DAU is prohibitively expensive server-side. Local prefetch + debounced GET achieves the same UX at a fraction of the cost.

---

### Reservation Holds

**Problem:** Two users booking the same room simultaneously. 15-minute payment window must be enforced.

**Server-owned lock + client countdown:**

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

**Key decision:** Client timer is cosmetic only — the server clock is authoritative. Rejected: WebSockets, long-polling, server-sent events. Server timestamp + client countdown is sufficient and far simpler.

---

### Payment Processing

**Why Stripe?** App must never handle raw card data. Stripe SDK collects card info, validates, and returns a token.

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

`PaymentService` (Domain Service) handles the Stripe SDK UI interaction to collect a token, then delegates to `ProcessPaymentUseCase` → `PaymentRepository: PaymentRepositoryProtocol` → `PaymentRemoteDataSource` → API. `PaymentViewModel` calls `PaymentService` via `PaymentServiceProtocol` — never the Stripe SDK directly. Swapping payment providers = one change in `PaymentRemoteDataSource`, nothing else.

---

## Trade-off Summary

| Decision | Chosen | Rejected | Why |
|----------|--------|---------|-----|
| Autocomplete | Prefetch + debounced HTTP GET | WebSocket streaming | Too expensive at 10M DAU |
| Reservation hold timer | Server timestamp + client countdown | WebSockets / long-poll | Simpler; server stays authoritative |
| Image caching | Manual `LocalFileDataSource` + CoreData TTL/LRU | URLSession default cache | Granular eviction control |
| Payment | Stripe SDK token | DIY card collection | PCI compliance; no raw card data on client |
| Pagination | Offset-limit | Cursor-based | Simpler; BE owns sort order; data doesn't move mid-scroll |
| Idempotency | Client-generated `local_id` UUID | Server dedup | Handles network retry duplicates cheaply |
| DI | Swinject | Manual init injection | Manages graph complexity at scale |
| Hotel List UI | UIKit `UITableView` | SwiftUI `List` | Granular scroll + pagination lifecycle control |

---

## Key Takeaways

- **Idempotency key** — always client-generated for mutation requests that could be retried
- **Server-authoritative timestamps** — never trust the client clock for business-critical windows (hold expiry)
- **Facade over third-party SDKs** — `PaymentService` wraps Stripe; `ImageService` wraps caching logic; rest of app calls protocols
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

---

*Interview verdict: Strong hire for Senior iOS. Candidate communicated trade-offs clearly, avoided over-engineering (rejected WebSockets twice), and kept complexity proportional to requirements.*
