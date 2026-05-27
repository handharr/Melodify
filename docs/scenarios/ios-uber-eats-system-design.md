# iOS Uber Eats — System Design

**Source:** YouTube — Staff iOS Engineer mock interview at Uber

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
- `[weak self]` in all closures to avoid retain cycles
- Coordinator-based navigation, manual init injection
- Mock-the-layer-below testing strategy
- `ThirdPartyDataSource` facade pattern — app calls protocol, never SDK directly
- Idempotency keys on mutations — `POST /orders` is retryable; generate UUID at `Param` call site
- HTTP `409 ≠ 5xx` — concurrency conflicts and transient server errors must never share a code path
- Infrastructure layer (`Gateway` suffix) — Domain defines protocol; concrete in Infrastructure; nothing depends on Gateway except DI wiring in Application

### What this scenario adds

| Concept | Generic | Uber Eats |
|---|---|---|
| Real-time updates | Not in generic | `OrderService` opens a persistent SSE connection; publishes `AnyPublisher<Order, AppError>` |
| SSE stream pattern | Not in generic | Multi-fire publisher (vs single-value UseCase); screen lifecycle scopes the connection |
| Server-hosted basket | Not in generic | Basket lives on backend for cross-device continuity; `BasketRepository` always writes remote on mutation |
| Image loading | Not in generic | `UIImageView` extension wrapping SDWebImage/Kingfisher — same facade pattern as `ThirdPartyDataSource` |
| Cross-device session state | Not in generic | `lastUsedAddress` on `User` drives restaurant list without an extra fetch |
| UI framework | SwiftUI default for new apps; UIKit when scroll lifecycle, AVPlayer, or custom transitions needed; hybrid valid screen-by-screen | UIKit throughout — restaurant list and menu use `UITableView`/`UICollectionView` for scroll lifecycle and pagination hooks; Order Status screen embeds `MKMapView` (custom view integration) |

### Key decisions unique to this scenario
- **SSE over polling.** Courier tracking sends updates every ~5 seconds. A 1-second poll for 10 minutes = 600 HTTP requests per order. SSE replaces all of that with one persistent connection. Polling is simpler to implement but wastes battery and overloads the backend.
- **SSE over WebSockets.** Courier tracking is unidirectional (server → client only). WebSockets add bidirectional complexity that this scenario doesn't need.
- **Server-hosted basket.** Basket state on the backend enables cross-device continuity (start on iPhone, finish on web). Trade-off: every basket mutation requires a network round-trip.
- **`OrderService` must close SSE on screen exit.** If the stream stays open after the Order Status screen is dismissed, it drains battery and holds a server connection. Close in `viewDidDisappear` equivalent.
- **`UIImageView` extension.** Restaurant and dish images are loaded via SDWebImage or Kingfisher, but always through a `UIImageView` extension — same isolation principle as `ThirdPartyDataSource`. Swapping the image library touches one file.

---

## Screens in Scope

| Screen | Description |
|---|---|
| Restaurant List | Address selector + list of nearby restaurants (name, image, rating) |
| Menu | Dish list for a selected restaurant (name, price, image); add to basket |
| Basket | View and edit selected dishes; place order (payment excluded) |
| Order Status | Current order status + courier real-time position on a map |

---

## Requirements

### Functional
- Choose a delivery address from saved addresses
- View nearby restaurants filtered by selected address
- Browse restaurant menus and add dishes to a basket
- Edit basket (change quantities, remove items), then place an order
- Track order status and courier position in real-time on a map
- Payment is out of scope

### Non-Functional
- Reasonable performance on slow mobile networks
- Optimise for limited on-device storage
- Do not overload the backend — no polling; prefer SSE for real-time updates

---

## Data Model

```swift
// Domain models — pure Swift structs, no UIKit or Foundation networking

struct User {
    let userID: Int
    let name: String
    let email: String
    let addresses: [Address]
    let lastUsedAddress: Address   // drives initial restaurant list without extra fetch
}

struct Address {
    let addressID: Int
    let label: String
    let city: String
    let street: String
    let flat: String
    let postcode: String
    let latitude: Double
    let longitude: Double
}

struct Restaurant {
    let restaurantID: Int
    let name: String
    let rating: Int
    let address: Address
    let imageURL: URL
}

struct Dish {
    let dishID: Int
    let restaurantID: Int           // FK: one-to-many with Restaurant
    let name: String
    let price: Double
    let imageURL: URL
}

struct Basket {
    let basketID: Int
    let userID: Int
    let restaurantID: Int
    let selectedDishes: [(dishID: Int, count: Int)]
}

struct Order {
    let orderID: Int
    let status: OrderStatus
    let basket: Basket
    let courierLocation: CLLocationCoordinate2D  // updated via SSE
}

enum OrderStatus {
    case placed, preparing, pickedUp, inTransit, delivered, cancelled
}
```

---

## API Design

### REST Endpoints

| # | Method | Path | Body | Returns |
|---|--------|------|------|---------|
| 1 | GET | `/users/<userID>` | — | `UserDTO` |
| 2 | GET | `/restaurants/<addressID>` | — | `[RestaurantDTO]` |
| 3 | GET | `/dishes/<restaurantID>` | — | `[DishDTO]` |
| 4 | POST | `/basket` | `{userID, restaurantID, dishID, count}` | `BasketDTO` |
| 5 | PATCH | `/basket` | `{basketID, dishID, count}` | `BasketDTO` |
| 6 | GET | `/basket/<basketID>` | — | `BasketDTO` |
| 7 | POST | `/orders` | `{userID, basketID, idempotencyKey}` | `OrderDTO` |
| 8 | GET | `/orders/<orderID>` | — | `OrderDTO` |

### SSE Endpoint

| # | Method | Path | Returns |
|---|--------|------|---------|
| 9 | GET | `/live-order-status/<orderID>` | `text/event-stream` — courier coords + status per event |

**Why idempotency on `POST /orders`?** If the network times out after the server creates the order, the app may retry. Without an idempotency key the server creates a duplicate order. Include a client-generated UUID (`localId`) in the body — server returns the existing record on duplicate submission. Key is generated at the `CreateOrderParam` call site, not inside the Repository.

---

## Architecture

### Layer Breakdown

```
Presentation
  ViewController (UIKit)
    └─ owns ViewModel (strong ref)
    └─ binds @Published state via Combine sink
    └─ calls ViewModel on user actions
    └─ calls Coordinator for navigation
    └─ subscribes/cancels OrderService publisher with screen lifecycle

  ViewModel (@MainActor, @Published)
    └─ calls UseCases for all one-shot actions
    └─ subscribes to OrderService.orderUpdates for live tracking
    └─ maps Domain → UIModel, never exposes Domain types to View

Domain
  UseCases (stateless, one per user action)
    FetchUserUseCase
    FetchRestaurantsUseCase    → RestaurantRepositoryProtocol
    FetchDishesUseCase         → DishRepositoryProtocol
    CreateBasketUseCase        → BasketRepositoryProtocol
    UpdateBasketUseCase        → BasketRepositoryProtocol
    FetchBasketUseCase         → BasketRepositoryProtocol
    CreateOrderUseCase         → OrderRepositoryProtocol

  Domain Service (stateful / long-lived)
    OrderService
      └─ opens SSE connection via OrderSSEGatewayProtocol.stream(orderID:)
      └─ closes SSE connection on stopTracking()
      └─ publishes AnyPublisher<Order, AppError> for ViewModel to bind
      └─ must be scoped to the Order Status screen, not app-scoped
         (no global playback state — only active while tracking screen is visible)

Data
  RestaurantRepository  : RestaurantRepositoryProtocol
    └─ RestaurantRemoteDataSource  → APIClient → GET /restaurants/<addressID>
    └─ RestaurantLocalDataSource   → Core Data (cache for offline restore)
    └─ RestaurantMapper            (DTO → Restaurant)

  DishRepository        : DishRepositoryProtocol
    └─ DishRemoteDataSource
    └─ DishLocalDataSource         → Core Data
    └─ DishMapper

  BasketRepository      : BasketRepositoryProtocol
    └─ BasketRemoteDataSource      → APIClient → POST/PATCH/GET /basket
    └─ BasketLocalDataSource       → Core Data (local mirror for instant restore)
    └─ BasketMapper

  OrderRepository       : OrderRepositoryProtocol
    └─ OrderRemoteDataSource       → APIClient → POST/GET /orders
    └─ OrderMapper

Infrastructure
  OrderSSEGateway: OrderSSEGatewayProtocol
    └─ wraps SSE client library
    └─ returns AsyncStream<OrderSSEEventDTO>
    └─ Domain defines the protocol; only Application wires the concrete

Application
  AppCoordinator
    └─ wires window → root tab bar
    └─ composes all dependencies via manual init injection
    └─ creates OrderService at coordinator level for the order flow
  
  RestaurantCoordinator, BasketCoordinator, OrderCoordinator
    └─ each owns its UseCase composition
    └─ handles push/pop and state passing between screens
```

### High-Level Diagram

```
ViewController ──→ ViewModel ──→ UseCases ──→ Repository ──→ RemoteDataSource ──http──→ REST API
                        │                                  └─→ LocalDataSource ──→ Core Data
                        │
                        └──→ OrderService ──→ OrderSSEGateway ──sse──→ SSE API

ViewController ──→ UIImageView extension ──→ SDWebImage/Kingfisher ──http──→ Image CDN

DI: Coordinator composes all dependencies via manual init injection (no framework)
```

---

## Vocabulary Mapping

| Video term | User's Clean Architecture equivalent | Notes |
|---|---|---|
| `Presenter` | `ViewModel` | MVVM eliminates the back-reference: ViewModel has no reference to the View. ViewController subscribes to `@Published` state via Combine sink. |
| `Router` | `Coordinator` | Direct equivalent. One Coordinator per flow. |
| `RestaurantService` | `FetchRestaurantsUseCase` + `RestaurantRepository` | Stateless per-action logic → UseCase. Data access → Repository. |
| `BasketService` | `CreateBasketUseCase` / `UpdateBasketUseCase` + `BasketRepository` | Same split. |
| `OrderService` (with SSE) | `OrderService` + `OrderSSEGateway` | Stateful/long-lived → Domain Service. SSE client → Infrastructure Gateway (`OrderSSEGateway: OrderSSEGatewayProtocol`). |
| `AuthService` | `Domain Service: SessionService` | Stateful session — app-scoped Domain Service. |
| `Network Client (Alamofire)` | `APIClient` (URLSession-based) | Generic HTTP client. Alamofire is a valid implementation detail inside `RemoteDataSource`. |
| `Mapper` | `Mapper` | Same name, same role. `static func toDomain(_ dto: DTO) -> Model?` |
| `Storage Facade / Core Data` | `RestaurantLocalDataSource`, `DishLocalDataSource`, `BasketLocalDataSource` wrapping Core Data | Each domain entity gets its own named `LocalDataSource`. Swapping Core Data for GRDB touches those files only. |
| `SSE Client` | `OrderSSEGateway: OrderSSEGatewayProtocol` (Infrastructure) | Wraps SSE library; returns `AsyncStream<DTO>`; Domain defines the protocol; rest of app never sees the library. |
| `UIImageView Extension` | `ThirdPartyDataSource` facade pattern | Same isolation principle — call site calls `imageView.setImage(url:)`, never the library directly. |
| `Swinject DI container` | Manual init injection via `Coordinator` | User's arch avoids framework DI. Swinject adds a dependency and potential init-time crashes. |

---

## Data Flow

### Restaurant List Screen

```
1. AppCoordinator reads User.lastUsedAddress from UserRepository (.cached)
2. RestaurantListViewModel.load(policy: .cached)
     → FetchRestaurantsUseCase.execute(param: FetchRestaurantsParam(addressID:))
         → RestaurantRepository
             1. RestaurantLocalDataSource.fetch() → cached DTOs → Mapper → [Restaurant] → UI renders instantly
             2. RestaurantRemoteDataSource.fetch() → GET /restaurants/<addressID> → DTO → Mapper → [Restaurant]
             3. RestaurantLocalDataSource.save(dtos) → Core Data updated
         → ViewModel maps [Restaurant] → [RestaurantUIModel]
         → @Published restaurantList updated → ViewController re-renders
         → defer: isLoading = false
```

### Place Order

```
BasketViewModel.placeOrder()
     → CreateOrderUseCase.execute(param: CreateOrderParam(userID:, basketID:, idempotencyKey: UUID()))
         → OrderRepository.create(param:)
             → OrderRemoteDataSource.post(/orders, body) → OrderDTO → Mapper → Order
         → ViewModel navigates to Order Status screen via Coordinator
```

### Order Status Screen — SSE Flow

```
OrderStatusViewController.viewDidAppear()
     → OrderStatusViewModel.startTracking(orderID:)
         → OrderService.startTracking(orderID:)
             → orderSSEGateway.stream(orderID:) → AsyncStream<OrderSSEEventDTO>   // OrderSSEGatewayProtocol (Infrastructure)
             → for await event in stream → OrderMapper.toDomain(event) → Order
             → publishes Order via AnyPublisher<Order, AppError>
         → ViewModel.orderUpdates sink → maps Order → OrderUIModel
         → @Published courierLocation + orderStatus updated → map pin moves + label updates

OrderStatusViewController.viewDidDisappear()
     → OrderStatusViewModel.stopTracking()
         → OrderService.stopTracking()  ← closes SSE connection immediately
```

---

## Deep Dives

### SSE — Why Not Polling

A 1-second polling interval over a 10-minute order = 600 HTTP requests. Each request creates a new TCP connection (or reuses a keep-alive connection), sends headers (~400 bytes), and most responses return no new data. SSE replaces this with one persistent connection where the server writes only when state changes.

```
Polling path (bad):
  t=0s  GET /orders/{id} → 200 "preparing"   ← unnecessary
  t=1s  GET /orders/{id} → 200 "preparing"   ← unnecessary
  ...
  t=47s GET /orders/{id} → 200 "picked_up"   ← useful
  ...600 requests, 599 wasted

SSE path (good):
  t=0s  GET /live-order-status/{id}           ← one persistent connection
  t=47s ← server writes: {status: "picked_up", lat: 1.3, lng: 103.8}
  t=89s ← server writes: {status: "in_transit", lat: 1.31, lng: 103.81}
```

### SSE vs WebSockets

| | SSE | WebSocket |
|---|---|---|
| Direction | Server → client only | Bidirectional |
| Protocol | HTTP/1.1 or HTTP/2 | ws:// (separate protocol) |
| Reconnection | Browser/client auto-reconnects | Manual |
| Use case | Courier tracking, notifications | Chat, collaborative editing |
| Complexity | Simple | Higher |

Courier tracking is read-only from the client's perspective — SSE is sufficient.

### `OrderService` — Scoping

Unlike `PlayerService` in the music streaming scenario (which must be app-scoped to keep audio playing when screens change), `OrderService` should be scoped to the order tracking flow — created by `OrderCoordinator` when the Order Status screen is pushed, destroyed when the coordinator is deallocated.

**Why not app-scoped?** There is no reason to maintain an SSE connection when the user is not on the Order Status screen. Keeping it alive wastes battery and server resources.

**Why not ViewController-scoped?** If the ViewController is re-created (e.g. navigation stack manipulation), the service would be destroyed mid-stream. Coordinator ownership is the right granularity.

### Basket — Local Cache Strategy

The basket lives on the backend (primary source of truth) but is also cached in `BasketLocalDataSource` (Core Data). This serves two purposes:

1. **Instant restore** — if the app is killed and relaunched mid-basket, the local cache shows the last known state immediately while a `GET /basket` fetch runs in the background.
2. **Optimistic display** — after `PATCH /basket`, update the local cache immediately and return the cached model to the ViewModel. Reconcile with the server response when it arrives.

`FetchPolicy.cached` on `FetchBasketUseCase` implements this: return local first, then refresh from network.

---

## Common Pitfalls / Gotchas

- **Not closing SSE on screen exit.** Stream stays open, drains battery, holds a server connection. Always close in the ViewController's `viewDidDisappear` equivalent — call `stopTracking()` on the ViewModel, which calls `OrderService.stopTracking()`.
- **ViewModel must not hold a reference to its View.** This is the core MVVM contract — ViewController subscribes to `@Published` state via Combine, ViewModel has no back-reference to the View. The MVP pattern (`weak var view: ViewProtocol?`) creates two-way coupling that makes the ViewModel untestable without a mock View.
- **UseCases and Domain Services must not call networking directly.** Networking belongs in `RemoteDataSource`. The correct chain is `UseCase → Repository → RemoteDataSource → APIClient`. A service that calls `NetworkClient` directly bypasses the Repository abstraction and couples the Domain layer to the Data layer.
- **Swinject init-time crashes.** Registrations missing at app startup cause crashes only at first use, not at boot — making them hard to detect in testing. Manual init injection via Coordinator exposes all dependencies at compile time.
- **No idempotency key on order creation.** POST /orders is the highest-risk mutation — a network timeout on the client while the server succeeded creates a duplicate order. Always generate a UUID at the `CreateOrderParam` call site.
- **`[weak self]` missing in Combine sinks.** `OrderStatusViewModel` subscribes to `OrderService.orderUpdates`. If `AnyCancellable` is stored correctly and `self` is captured weakly, this is fine. Forgetting `[weak self]` creates a retain cycle that prevents the ViewModel from deallocating.

---

## Interviewer Feedback / Key Takeaways

- The core data flow is: address → restaurant list → menu → basket (server-hosted, locally cached) → order (with idempotency key) → SSE stream for live tracking.
- SSE is the correct choice for courier tracking — unidirectional, persistent, no polling overhead. Justify it against polling and WebSockets.
- MVVM keeps the ViewModel testable without a mock View. MVP's back-reference to View is the specific weakness MVVM eliminates.
- Every Repository and Domain Service is injected via protocol — Coordinators compose the full graph at the composition root. No framework DI needed.
- The basket on the backend is the key cross-platform decision. Local cache (Core Data) provides fast UI restore; the backend is the source of truth.
- In the interview, communicate continuously — propose a direction, pause for feedback, then build. State architecture rationale before drawing the diagram. Walk the data flow end-to-end immediately after finishing the diagram.
