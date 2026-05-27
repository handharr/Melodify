# iOS App System Design — Generic Architecture

My default architecture for any iOS app. Carry this into every interview.  
Scenario-specific docs extend this — they describe the delta, not a replacement.

---

## Architecture Pattern

**Clean Architecture + MVVM + UIKit**

```
Presentation    →  ViewController + ViewModel (Combine @Published)
Domain          →  UseCase + Service + Protocol + Model + Param + FetchPolicy
Data            →  Repository + DataSource + DTO + Mapper + APIClient
Infrastructure  →  Gateway (external SDK + OS framework facades)
Application     →  AppDelegate + Coordinator + DI (manual init injection)
```

**Layer dependency rule: Presentation → Domain ← Data. Infrastructure conforms to Domain protocols. Domain depends on nothing.**

The Data layer knows Domain models (via Mapper). The Presentation layer knows Domain models (via UseCase). Infrastructure implements Domain protocols but is never imported by Domain, Data, or Presentation — only wired by Application.

---

## Why These Choices

### Clean Architecture over MVC
MVC in iOS degrades to Massive ViewController — business logic, networking, and layout all end up in one file. Clean Architecture enforces the dependency rule so each layer is independently testable and replaceable. Cost: more files. Benefit: every layer can be tested without the others.

### MVVM over MVP
In MVP the Presenter holds a reference back to the View via protocol — two-way coupling. MVVM breaks that: ViewModel exposes `@Published` state and has no reference to the View. ViewModels are easier to test (no mock View needed) and work naturally with Combine.

### MVVM over VIPER
VIPER splits a screen into 5 objects. The overhead is justified for very large teams where each layer is owned by a different person. For a small team, MVVM + UseCase gives the same testability with half the files.

### Infrastructure as the fourth layer
The three-layer model (Presentation → Domain ← Data) is a simplification of Clean Architecture's four-ring model. It breaks down for SDKs that span multiple layers — Stripe owns both Presentation (card collection UI) and Data (token API call): neither layer alone is the right home. Infrastructure is the explicit fourth layer for these cross-layer wrappers. The Gateway trigger is **cross-layer span**, not the presence of a third-party import.

**SDK placement rule — scope-based, not import-based:**
- SDK spans multiple layers (Presentation + Data, etc.) → **Gateway** in Infrastructure (e.g. Stripe, Firebase with Auth + Analytics UI)
- SDK is data/persistence only → **DataSource** in Data (e.g. CoreData, Realm)
- SDK is domain logic only → **Service** in Domain (e.g. AVFoundation for playback orchestration)

**Why not `Manager`?** `Manager` became a dumping ground with no clear boundary — `NetworkManager`, `DataManager`, `AppManager`. Infrastructure is precise: every Gateway there answers the question *which cross-layer external system am I hiding?*

**Why `Gateway` as the suffix?** `Service` is claimed by Domain Services. `DataSource` is claimed by the Data layer. `Gateway` is unclaimed and semantically accurate — it is the entry point to an external system that spans layers the app doesn't own.

### UIKit vs SwiftUI — Which to Default To

**New app → SwiftUI.** SwiftUI is the current default for greenfield iOS development. State-driven rendering, declarative layout, and native support for `async`/`await` fit cleanly with the MVVM layer. The ViewModel exposes `@Published` state; the SwiftUI View subscribes with no Combine boilerplate needed.

**Legacy app → stay on UIKit.** Migrating an existing UIKit codebase is high risk for low gain. Hybrid apps add `UIHostingController` overhead and coordination complexity. Unless the team has a specific mandate to migrate, new screens in a UIKit app should remain UIKit.

**Where UIKit is still the right call even in a new app:**
- Screens that need granular scroll lifecycle (`willDisplay cell` for paginated fetches, sticky headers with custom offsets)
- Complex custom transitions and interruptible animations
- Direct `AVPlayerViewController` or `AVPlayerLayer` integration requiring lifecycle control
- Anything where SwiftUI's layout system cannot match the required pixel-level fidelity

**Hybrid UIKit/SwiftUI** is valid screen-by-screen. Coordinator wires them together. UIKit screens host SwiftUI content via `UIHostingController`; SwiftUI screens embed UIKit views via `UIViewRepresentable`. Rule of thumb: if a screen needs `UITableView`/`UICollectionView` lifecycle control, use UIKit. If it's primarily reactive state → UI, use SwiftUI.

---

## Layer Breakdown

### Presentation

```
ViewController
  └─ owns ViewModel (strong ref)
  └─ binds to @Published state via Combine sink
  └─ calls ViewModel methods on user actions
  └─ never calls UseCases or Repositories directly

ViewModel
  └─ @MainActor — all state on main thread, no DispatchQueue.main.async
  └─ @Published properties (tracks, isLoading, errorMessage)
  └─ calls UseCases
  └─ owns UIModel mappers (Domain → display model)
  └─ [weak self] in all closures
  └─ defer { isLoading = false } — guaranteed cleanup on success and failure
```

**UIModel** — a flat, display-ready struct. Never pass Domain models to the View directly. The ViewModel maps Domain → UIModel so the View has no knowledge of business types.

### Domain

```
UseCase
  └─ one public method: execute(policy:param:) async throws → Output
  └─ stateless — created per call or injected
  └─ orchestrates one business action
  └─ calls one or more Repository methods
  └─ never touches networking or storage directly

Domain Service
  └─ stateful or long-lived logic not tied to a single user action
  └─ injected and lives as long as needed (often app-scoped)
  └─ pure Swift — no UIKit imports, no SDK imports
  └─ examples: PlayerService, SessionService, AuthService

Model
  └─ pure Swift structs — no import UIKit, no import Foundation networking
  └─ the only type that crosses all layers

Param
  └─ typed struct for every UseCase input
  └─ split into path: and query: sub-structs
  └─ adding a field doesn't break existing call sites

FetchPolicy
  └─ .fresh   — always hit network, update cache
  └─ .cached  — return cache if available, else network
  └─ .strict  — cache only, throw on miss
  └─ travels from ViewModel → UseCase → Repository
  └─ Repository is the only place that interprets it
```

**UseCase vs Domain Service — when to use which:**

| | UseCase | Domain Service |
|---|---|---|
| Triggered by | User action | Another component |
| State | Stateless | Can be stateful |
| Lifetime | Per call | Injected, lives as needed |
| Imports | Nothing | Nothing (pure Swift) |

### Data

```
Repository
  └─ implements RepositoryProtocol (Domain interface)
  └─ coordinates RemoteDataSource and LocalDataSource
  └─ applies FetchPolicy: check local → fetch remote → write local
  └─ converts DTO → Domain Model via Mapper
  └─ never exposed to Presentation or Domain UseCases directly (only via protocol)

RemoteDataSource
  └─ wraps APIClient
  └─ builds request URLs and decodes responses
  └─ returns DTOs — never Domain models

LocalDataSource
  └─ wraps persistence (UserDefaults / SQLite / GRDB / Core Data)
  └─ returns DTOs — never Domain models
  └─ Repository never touches the storage backend directly

DTO (Data Transfer Object)
  └─ mirrors the API or DB schema exactly
  └─ Codable — conforms to external shape, not business shape
  └─ disposable: only lives between the network/DB and the Mapper

Mapper
  └─ the only type that knows both DTO and Domain model
  └─ static function: toDomain(_ dto: DTO) -> Model?
  └─ returns Optional — invalid data is silently dropped, never crashes

APIClient
  └─ generic HTTP client: get/post/put/delete
  └─ lives at Data/Network/ — not a separate layer
  └─ no domain knowledge
```

**DTO → Mapper → Domain Model flow:**

```
RemoteDataSource fetches JSON
  → decoded as DTO (Codable, mirrors API shape)
  → Mapper.toDomain(dto) → Domain Model (or nil if invalid)
  → Repository returns [Model] to UseCase
  → UseCase returns [Model] to ViewModel
  → ViewModel maps Model → UIModel for the View
```

Mapper is the seam between external data and your business logic. Keep it the only crossing point.

### Infrastructure

```
Gateway
  └─ concrete implementation of a Domain protocol (XxxGatewayProtocol)
  └─ wraps one external system — SDK, OS framework, or third-party service
  └─ may import UIKit, SDKs, OS frameworks — Domain never does
  └─ nothing depends on Gateway except DI wiring in Application
  └─ examples:
       StripePaymentGateway      → PaymentGatewayProtocol    (Stripe SDK)
       APNsNotificationGateway   → NotificationGatewayProtocol (UNUserNotificationCenter + APNs)
       FirebaseAnalyticsGateway  → AnalyticsGatewayProtocol  (Firebase SDK)
       LocalAuthGateway          → BiometricAuthGatewayProtocol (LocalAuthentication)
```

**Domain Service vs Gateway — when to use which:**

| | Domain Service | Gateway |
|---|---|---|
| Owns | Business logic + state | External system interaction |
| Imports | Nothing (pure Swift) | UIKit, SDK, OS frameworks |
| Layer | Domain | Infrastructure |
| Protocol lives in | Domain | Domain |
| Concrete lives in | Domain | Infrastructure |
| Example | `PlayerService`, `ReservationService` | `StripePaymentGateway`, `APNsNotificationGateway` |

**The rule:** the Gateway trigger is cross-layer span, not the presence of a third-party import. Use a Gateway when an SDK touches multiple layers — Stripe owns Presentation (card collection UI) and Data (token API call), so neither layer alone is the right home. Single-layer SDKs wrap where they naturally live: CoreData → `LocalDataSource` (Data), AVFoundation playback → `PlayerService` (Domain). Domain defines the protocol; Infrastructure provides the concrete.

```swift
// Domain — defines the contract, no SDK imports
protocol PaymentGatewayProtocol {
    func collectToken() async throws -> String
}

// Infrastructure — wraps Stripe (spans Presentation + Data), fulfills the contract
final class StripePaymentGateway: PaymentGatewayProtocol {
    func collectToken() async throws -> String { ... }
}

// Data — CoreData is persistence-only, wraps directly in DataSource (no Gateway needed)
final class TrackLocalDataSource: TrackLocalDataSourceProtocol {
    private let context: NSManagedObjectContext  // CoreData import stays in Data layer
    ...
}
```

**Suffix clarity — one suffix per layer:**

| Suffix | Layer | Example |
|---|---|---|
| `UseCase` | Domain | `SearchTracksUseCase` |
| `Service` | Domain | `PlayerService`, `ReservationService` |
| `Repository` | Data | `TrackRepository` |
| `DataSource` | Data | `TrackRemoteDataSource` |
| `Gateway` | Infrastructure | `StripePaymentGateway` |

### Application

```
AppDelegate
  └─ entry point — wires window and root coordinator
  └─ registers app-scoped services (analytics, player, auth)

Coordinator
  └─ owns navigation logic — ViewControllers never push/present directly
  └─ creates UseCases and ViewModels (DI composition root)
  └─ one coordinator per flow

DI (manual init injection)
  └─ no DI framework — dependencies passed through init
  └─ no default concrete arguments on Repository or UseCase inits
  └─ DataSources and APIClient composed at Coordinator level
```

---

## Dependency Injection — The Rule

Dependencies flow inward. Each layer receives its dependencies via init. No layer constructs its own dependencies.

```swift
// Coordinator (composition root) — builds the full graph
let client = APIClient()
let remoteDataSource = TrackRemoteDataSource(client: client)
let localDataSource = TrackLocalDataSource()
let repository = TrackRepository(remote: remoteDataSource, local: localDataSource)
let useCase = SearchTracksUseCase(repository: repository)
let viewModel = TrackListViewModel(searchTracks: useCase)
```

**No default concrete args in Repository inits.** The default should come from the DI registration, not the init signature. Default args that instantiate concrete types hide dependencies and make testing harder.

---

## Generic Data Flows

### Read flow (e.g. load a screen)

`async/await` is single-return — `UseCase.execute()` returns once. Offline-first (cache renders immediately, then network updates) requires **two separate awaits** in the ViewModel.

#### Pattern A — Two awaits (canonical)

```
ViewController.viewDidLoad()
  → ViewModel.load()
      → isLoading = true

      // Phase 1 — cache (instant)
      if let cached = try? await UseCase.execute(policy: .strict, param:)
          → Repository checks LocalDataSource only — throws on miss
          → ViewModel maps cached Model → UIModel
          → @Published state updated → View renders immediately

      // Phase 2 — network (background)
      let fresh = try await UseCase.execute(policy: .fresh, param:)
          → Repository fetches RemoteDataSource → DTO → Mapper → Model
          → LocalDataSource.save(dto)
          → ViewModel maps Model → UIModel
          → @Published state updated → View refreshes

      → defer: isLoading = false
```

**Why two calls, not one?** `async/await` returns once. A single `execute(policy: .cached)` can only yield one value — it can't update the UI twice. For cache-then-network, the ViewModel must make two distinct awaits, one per phase.

**`.strict` for phase 1, `.fresh` for phase 2.** `.strict` = cache only, throws on miss (zero network cost). The `try?` suppresses the throw so a cold cache silently skips phase 1 and the user just sees a brief loading state before the network result arrives. `.fresh` = always hits network regardless of cache state.

#### Pattern B — AsyncStream (alternative)

The UseCase returns an `AsyncStream<[Model]>` that yields twice — cache first, network second. The ViewModel iterates with `for await`. Use this when the two-phase logic is shared across many screens and repeating two calls per ViewModel becomes noisy.

| | Pattern A (two awaits) | Pattern B (AsyncStream) |
|---|---|---|
| ViewModel code | Two explicit awaits | Single `for await` loop |
| Testability | Easy — stub UseCase per call | Requires async stream mocking |
| UseCase reuse | `.strict` / `.fresh` are independent | Two-phase baked into one UseCase |
| Complexity | Low | Higher |

**Default to Pattern A.** Pattern B is a valid optimization when two-phase loading is a cross-cutting concern, not a one-off.

### Mutation flow (e.g. create / update)

```
ViewController sends user input
  → ViewModel.submit(input)
      → isLoading = true
      → UseCase.execute(param:)
          → (validates param — throws if invalid)
          → Repository.create/update(param:)
              → RemoteDataSource.post/put() → DTO → Mapper → Model
          → returns Model
      → ViewModel maps Model → UIModel → updates @Published state
      → defer: isLoading = false
```

**Idempotency keys on mutations** — for any mutation that could be retried (network timeout, app restart during request), generate a client-side UUID before building the request and include it as a field (e.g. `localId`). If the request is retried with the same UUID, the server returns the existing record rather than creating a duplicate. This applies to reservations, orders, payments, and any operation where a duplicate would cause business harm. The UUID is generated at the `Param` struct call site, not inside the Repository or DataSource.

---

## Networking

```
APIClient
  └─ URLSession-based generic HTTP client
  └─ func get<T: Decodable>(_ url: URL) async throws -> T
  └─ func post<T: Decodable, B: Encodable>(_ url: URL, body: B) async throws -> T

Request structs
  └─ one per endpoint: TrackSearchRequest, CreatePlaylistRequest, etc.
  └─ carries the fields needed to build the URL and body
  └─ lives at Data/Network/Requests/

Error handling
  └─ typed APIError enum: .invalidURL, .notFound, .networkError, .decodingError, .conflict
  └─ propagates async throws up to ViewModel
  └─ ViewModel catches and sets errorMessage: String?

HTTP status code semantics — map at the RemoteDataSource level, never in the ViewModel:
  └─ 4xx client errors:
       └─ 400 Bad Request    — malformed request; log and show generic error
       └─ 401 Unauthorized   — session expired; trigger re-auth flow
       └─ 403 Forbidden      — user lacks permission; show access denied
       └─ 404 Not Found      — resource gone; remove from local cache
       └─ 409 Conflict       — concurrency conflict (e.g. item already claimed by another user)
                               → distinct error path with specific UX, NOT a generic retry
  └─ 5xx server errors       — transient; show retry UI
  └─ network timeout         — transient; show retry UI

409 and 5xx must never share a code path. A 409 means a specific domain event occurred
(another user acted first) and requires domain-specific UX. A 5xx means "try again later."
```

**APIClient lives inside the Data layer, not a separate Network layer.** It's an implementation detail of RemoteDataSources. Nothing in Domain or Presentation touches it.

---

## Persistence

```
LocalDataSource
  └─ wraps the storage backend (UserDefaults / GRDB / Core Data)
  └─ Repositories never touch the backend directly — always through LocalDataSource
  └─ stores and retrieves DTOs, not Domain models
  └─ keyed by request parameters for cache lookup

Storage backend choice:
  └─ UserDefaults   — simple key-value cache, small payloads
  └─ GRDB (SQLite)  — relational queries, Combine publishers, no magic
  └─ Core Data      — only if CloudKit sync or existing stack required
```

**Why wrap storage in LocalDataSource?**
The Repository doesn't know or care what's underneath. Swapping UserDefaults for GRDB touches one file — `LocalDataSource` — and nothing else.

---

## Navigation

```
Coordinator pattern
  └─ AppCoordinator — root, owns tab bar, handles deep links
  └─ FeatureCoordinator (e.g. SearchCoordinator, HomeCoordinator) — one per flow
  └─ ViewControllers never call push/present directly
  └─ deep links handled at AppCoordinator level, delegated to feature coordinators

Deep link flow:
  NotificationCenter.post(.handleDeepLink, object: link)
    → AppCoordinator.handle(link)
        → selects correct tab
        → delegates to feature coordinator
        → feature coordinator creates ViewModel + ViewController and pushes
```

App-scoped services (e.g. PlayerService) must be registered at AppCoordinator level — not owned by any ViewController. If owned by a ViewController, they deallocate when that screen is popped.

---

## Concurrency

```
@MainActor on ViewModel — all state mutations on main thread
async/await throughout — no completion handlers
async let — two concurrent fetches
withThrowingTaskGroup — N concurrent fetches
[weak self] — all closures that capture self
defer { isLoading = false } — cleanup on any exit path
```

**`async let` vs `withThrowingTaskGroup`:**

| | `async let` | `withThrowingTaskGroup` |
|---|---|---|
| Use when | Fixed small N (2–3) | Dynamic N |
| Syntax | Cleaner | More explicit |
| Example | Fetch tracks + playlists | Fetch detail for each item in a list |

---

## Testing Strategy

**Rule: mock the layer below, assert on the layer you just built.**

| Layer | What to mock | What to assert |
|---|---|---|
| ViewModel | MockUseCase | @Published state after action |
| UseCase | MockRepository | Return value, thrown error |
| Repository | MockRemoteDataSource + MockLocalDataSource | FetchPolicy logic, Mapper output |
| DataSource | MockAPIClient / in-memory DB | Request shape, response decoding |
| Gateway | MockGatewayProtocol (in Domain tests) | Protocol method called, correct input forwarded |

```
MockUseCase
  └─ var stubbedResult: Result<Output, Error>
  └─ private(set) var lastParam: Param?
  └─ func execute(...) async throws → returns stubbedResult

Test pattern:
  1. Arrange: set stubbed result on mock
  2. Act: call ViewModel/UseCase method
  3. Assert: check @Published state or return value
```

No mocking of concrete types. Every dependency is injected via a protocol — replace with mock in tests, real impl in production.

---

## Adapting to a Scenario

When given an interview problem, map it onto this architecture:

1. **Identify the domain** — what are the entities? (Track, Playlist, User, Order…)
2. **Name the Repositories** — one per domain entity or aggregate
3. **Name the UseCases** — one per user action or screen load
4. **Identify Domain Services** — anything stateful, long-lived, or shared across screens
5. **Apply FetchPolicy** — does this screen need fresh data? Can it show stale?
6. **Identify the local storage need** — cache only, or offline-first with user-controlled saves?
7. **Identify external SDKs** — does the SDK span multiple layers? If yes → Gateway in Infrastructure (e.g. Stripe: Presentation + Data). If data/persistence only → DataSource in Data (e.g. CoreData). If domain logic only → Service in Domain (e.g. AVFoundation for playback). The Gateway trigger is cross-layer span, not a third-party import.
8. **Draw the data flow** — top to bottom, out loud, immediately after the diagram

The scenario doc fills in the specifics. This doc is the skeleton.

---

## Recall Table — Visual Rules

The `system-design-recall.html` summary table follows these rules to keep the diagram unambiguous.

### Column structure

9 columns, left to right:

```
Flow | Storage | Network | Infrastructure | Repository | DataSource | UseCase | Service | Presentation
```

Data and Domain are each split into two sub-columns so each entity type is independently scannable top-to-bottom.

### Component uniqueness

Each named component appears **at most once** per layer column per scenario card. Showing the same chip twice in two differently-colored rows creates a false signal — the color implies the component belongs to that flow exclusively, when it participates in multiple.

### Consecutive reuse — rowspan + flow dots

When the same component participates in N **consecutive** flows:

1. Merge the N cells with `rowspan="N"`.
2. Render the chip with `.chip.shared` (neutral `var(--text)` color — no flow color).
3. Add a `<div class="flow-dots">` beneath the chip — one `<span class="flow-dot">` per participating flow, tinted with that flow's CSS variable.

This preserves "which flows use this component" without claiming the component is owned by any single flow.

### Non-consecutive reuse — ref badge

When the same component appears in non-consecutive rows (e.g. rows 1 and 4 with a different component in rows 2–3), rowspan is not possible. Show the chip normally in the first row; in each later non-consecutive row show the chip again followed by `<span class="ref-badge">↑</span>` to signal reuse.

### Rowspan decision criteria

**Rowspan when:**
- The chip is the sole or primary component in the cell (no two distinct components mixed in one cell)
- It appears in 2+ consecutive rows

**Do not rowspan:**
- DataSource cells — per-flow sub-notes carry distinct recall details (upsert strategy, FetchPolicy, retry behavior)
- Network cells — endpoints are always unique per flow
- Mixed-component cells (e.g. `APIClient + NWPathMonitor`)

### Flow color on unspanned rows

Chips in non-rowspanned cells inherit `currentColor` from `tr.f1–f5` as before. Only rowspanned chips use `.chip.shared` neutral color.
