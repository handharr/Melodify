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
- `async/await` for UseCase/Repository I/O
- `ThirdPartyDataSource` facade pattern — app calls protocol, never SDK directly
- Idempotency keys on mutations — `POST /orders` is retryable; generate UUID at `Param` call site
- Infrastructure and External layers follow the philosophy doc exactly — see there for Gateway/wrapper rules

### What this scenario adds

| Concept | Generic | Uber Eats |
|---|---|---|
| Real-time updates | Not in generic | `OrderService` opens a persistent SSE connection via `OrderSSEDataSource`; publishes `AnyPublisher<Order, AppError>` |
| SSE transport | Not in generic | Multi-fire publisher (vs single-value UseCase); screen lifecycle scopes the connection; `SSEClient` in Data (transport-only, same as `WebSocketClient` in ChatApp) |
| SSE publisher type | Not in generic | `AnyPublisher<Order, AppError>` chosen over `AsyncStream`: `OrderService` is a Domain Service living alongside other `@Published` Combine state in the ViewModel; Combine backpressure operators (debounce, throttle) are available for rapid SSE events |
| Server-hosted basket | Not in generic | Basket lives on backend for cross-device continuity; `BasketRepository` always writes remote on mutation |
| Image loading facade | Not in generic | `UIImageView` extension wrapping SDWebImage/Kingfisher — same facade pattern as `ThirdPartyDataSource`; swapping the library touches one file |
| Cross-device session state | Not in generic | `lastUsedAddress` on `User` drives restaurant list without an extra fetch |
| UIKit choice | SwiftUI default for new apps; UIKit when scroll lifecycle, AVPlayer, or custom transitions needed | UIKit throughout — restaurant list and menu use `UITableView`/`UICollectionView` for scroll lifecycle and pagination hooks; Order Status screen embeds `OrderMapView` (UIView subclass wrapping `MKMapView`); MapKit requires direct lifecycle control |
| `OrderService` scoping | Not in generic | Scoped to `OrderCoordinator` (not app-scoped); destroyed when coordinator deallocates; no reason to hold an SSE connection outside the Order Status screen |

### Key decisions unique to this scenario
- **SSE over polling.** Courier tracking sends updates every ~5 seconds. A 1-second poll for 10 minutes = 600 HTTP requests per order. SSE replaces all of that with one persistent connection.
- **SSE over WebSockets.** Courier tracking is unidirectional (server → client only). WebSockets add bidirectional complexity that this scenario doesn't need.
- **Server-hosted basket.** Basket state on the backend enables cross-device continuity (start on iPhone, finish on web). Trade-off: every basket mutation requires a network round-trip.
- **`OrderService` must close SSE on screen exit.** If the stream stays open after the Order Status screen is dismissed, it drains battery and holds a server connection. Close in `viewDidDisappear` equivalent.
- **`UIImageView` extension.** Restaurant and dish images are loaded via SDWebImage or Kingfisher, but always through a `UIImageView` extension — same isolation principle as `ThirdPartyDataSource`. Swapping the image library touches one file.

---

## 1. Requirements

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

### Screens in Scope

| Screen | Description |
|---|---|
| Restaurant List | Address selector + list of nearby restaurants (name, image, rating) |
| Menu | Dish list for a selected restaurant (name, price, image); add to basket |
| Basket | View and edit selected dishes; place order (payment excluded) |
| Order Status | Current order status + courier real-time position on a map |

---

## 2. API Design

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

`CreateOrderParam` includes `idempotencyKey: UUID()` generated at the call site (not in Repository or DataSource).

---

## 3. Data Model

### Domain Models

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
    let courierLatitude: Double     // updated via SSE
    let courierLongitude: Double    // updated via SSE
}

enum OrderStatus {
    case placed, preparing, pickedUp, inTransit, delivered, cancelled
}
```

### DTOs (Codable, mirror wire format)

```swift
struct UserDTO: Codable {
    let userID: Int
    let name: String
    let email: String
    let addresses: [AddressDTO]
    let lastUsedAddressID: Int
}

struct AddressDTO: Codable {
    let addressID: Int
    let label: String
    let city: String
    let street: String
    let flat: String
    let postcode: String
    let latitude: Double
    let longitude: Double
}

struct RestaurantDTO: Codable {
    let restaurantID: Int
    let name: String
    let rating: Int
    let address: AddressDTO
    let imageURL: String
}

struct DishDTO: Codable {
    let dishID: Int
    let restaurantID: Int
    let name: String
    let price: Double
    let imageURL: String
}

struct BasketDTO: Codable {
    let basketID: Int
    let userID: Int
    let restaurantID: Int
    let selectedDishes: [BasketItemDTO]
}

struct BasketItemDTO: Codable {
    let dishID: Int
    let count: Int
}

struct OrderDTO: Codable {
    let orderID: Int
    let status: String          // OrderStatus raw value
    let basket: BasketDTO
    let courierLatitude: Double
    let courierLongitude: Double
}

// SSE event — decoded from text/event-stream data field
struct OrderSSEEventDTO: Codable {
    let orderID: Int
    let status: String
    let courierLatitude: Double
    let courierLongitude: Double
}
```

---

## 4. High-Level Design

```
┌─────────────────────────────────────────────────────────────────────┐
│  Presentation  (UIKit · Combine)                                    │
│  RestaurantListViewController / RestaurantListViewModel             │
│  MenuViewController / MenuViewModel                                 │
│  BasketViewController / BasketViewModel                             │
│  OrderStatusViewController / OrderStatusViewModel                   │
│  OrderMapView (UIView subclass wrapping MKMapView)                  │
│  UIImageView extension — wraps SDWebImage/Kingfisher                │
│  UIModels: RestaurantUIModel, DishUIModel,                          │
│            BasketUIModel, OrderUIModel                              │
└────────────────────────────┬────────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────────┐
│  Domain                                                             │
│  FetchUserUseCase           → UserRepositoryProtocol               │
│  FetchRestaurantsUseCase    → RestaurantRepositoryProtocol         │
│  FetchDishesUseCase         → DishRepositoryProtocol               │
│  CreateBasketUseCase        → BasketRepositoryProtocol             │
│  UpdateBasketUseCase        → BasketRepositoryProtocol             │
│  FetchBasketUseCase         → BasketRepositoryProtocol             │
│  CreateOrderUseCase         → OrderRepositoryProtocol              │
│                                                                     │
│  OrderService (Domain Service — scoped to OrderCoordinator)        │
│    opens SSE via OrderSSEDataSourceProtocol.stream(orderID:)       │
│    publishes AnyPublisher<Order, AppError>                         │
│    OrderSSEDataSourceProtocol lives in Domain/Interfaces/          │
│                                                                     │
│  Models: User, Address, Restaurant, Dish, Basket, Order,           │
│          OrderStatus                                                │
│  Params: FetchUserParam, FetchRestaurantsParam,                    │
│          FetchDishesParam, CreateBasketParam,                       │
│          UpdateBasketParam, FetchBasketParam,                       │
│          CreateOrderParam(userID:, basketID:,                       │
│                          idempotencyKey: UUID)                      │
└────────────────────────────┬────────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────────┐
│  Data                                                               │
│  UserRepository        → UserRemoteDataSource                      │
│                        → UserLocalDataSource                        │
│  UserRemoteDataSource                  [URLSession · APIClient]    │
│  UserLocalDataSource                   [CoreData]                  │
│                                                                     │
│  RestaurantRepository  → RestaurantRemoteDataSource                │
│                        → RestaurantLocalDataSource                 │
│  RestaurantRemoteDataSource            [URLSession · APIClient]    │
│  RestaurantLocalDataSource             [CoreData]                  │
│                                                                     │
│  DishRepository        → DishRemoteDataSource                      │
│                        → DishLocalDataSource                       │
│  DishRemoteDataSource                  [URLSession · APIClient]    │
│  DishLocalDataSource                   [CoreData]                  │
│                                                                     │
│  BasketRepository      → BasketRemoteDataSource                    │
│                        → BasketLocalDataSource                     │
│  BasketRemoteDataSource                [URLSession · APIClient]    │
│  BasketLocalDataSource                 [CoreData]                  │
│                                                                     │
│  OrderRepository       → OrderRemoteDataSource                     │
│  OrderRemoteDataSource                 [URLSession · APIClient]    │
│                                                                     │
│  OrderSSEDataSource    : OrderSSEDataSourceProtocol                │
│    └─ SSEClient (wraps URLSession persistent GET, text/event-stream)│
│    └─ returns AsyncStream<OrderSSEEventDTO>                        │
│  SSEClient                             [URLSession]                │
│    └─ transport-only peer to APIClient                             │
│    └─ receive() → AsyncStream<Data> / disconnect()                 │
│                                                                     │
│  Mappers: UserMapper, RestaurantMapper, DishMapper,                │
│           BasketMapper, OrderMapper                                 │
└────────────────────────────┬────────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────────┐
│  Application                                                        │
│  AppCoordinator           [UIKit]                                  │
│    wires window → root tab bar                                      │
│    composes all dependencies via manual init injection              │
│  RestaurantCoordinator, BasketCoordinator                          │
│  OrderCoordinator                                                   │
│    creates and owns OrderService for the order tracking flow        │
│    destroys OrderService on deallocation                            │
└────────────────────────────┬────────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────────┐
│  Infrastructure                                                     │
│  None                                                               │
└────────────────────────────┬────────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────────┐
│  Dependencies                                                       │
│  URLSession        persistent GET (SSEClient) · request/response   │
│  CoreData          NSPersistentContainer · NSManagedObjectContext   │
│  MapKit            MKMapView (wrapped by OrderMapView in Presentation)│
│  SDWebImage / Kingfisher   image loading (wrapped by UIImageView ext)│
└─────────────────────────────────────────────────────────────────────┘
```

**Navigation (Coordinator pattern)**

```
AppCoordinator (root, tab bar)
  └── RestaurantCoordinator
        └── RestaurantListViewController
              └── MenuViewController (pushed on restaurant tap)
  └── BasketCoordinator
        └── BasketViewController
  └── OrderCoordinator (created on place order)
        └── OrderStatusViewController
```

`OrderCoordinator` is the composition root for the order tracking flow. It creates `OrderService` on init and injects it into `OrderStatusViewModel`. When `OrderCoordinator` is deallocated (user exits the order flow), `OrderService` is destroyed and the SSE connection is closed.

---

## Vocabulary Mapping

| Video term | Clean Architecture equivalent | Notes |
|---|---|---|
| `Presenter` | `ViewModel` | MVVM eliminates the back-reference: ViewModel has no reference to the View. ViewController subscribes to `@Published` state via Combine sink. |
| `Router` | `Coordinator` | Direct equivalent. One Coordinator per flow. |
| `RestaurantService` | `FetchRestaurantsUseCase` + `RestaurantRepository` | Stateless per-action logic → UseCase. Data access → Repository. |
| `BasketService` | `CreateBasketUseCase` / `UpdateBasketUseCase` + `BasketRepository` | Same split. |
| `OrderService` (with SSE) | `OrderService` + `OrderSSEDataSource` + `SSEClient` | Stateful/long-lived → Domain Service. SSE transport → Data (`SSEClient` wrapped by `OrderSSEDataSource: OrderSSEDataSourceProtocol`). |
| `AuthService` | `Domain Service: SessionService` | Stateful session — app-scoped Domain Service. |
| `Network Client (Alamofire)` | `APIClient` (URLSession-based) | Generic HTTP client. Alamofire is a valid implementation detail inside `RemoteDataSource`. |
| `Storage Facade / Core Data` | `RestaurantLocalDataSource`, `DishLocalDataSource`, `BasketLocalDataSource` wrapping Core Data | Each domain entity gets its own named `LocalDataSource`. Swapping Core Data for GRDB touches those files only. |
| `SSE Client` | `SSEClient` + `OrderSSEDataSource: OrderSSEDataSourceProtocol` (Data) | `SSEClient` wraps URLSession SSE stream; `OrderSSEDataSource` returns `AsyncStream<OrderSSEEventDTO>` to `OrderService`; same transport-only pattern as `WebSocketClient` in ChatApp. |
| `UIImageView Extension` | `ThirdPartyDataSource` facade pattern | Same isolation principle — call site calls `imageView.setImage(url:)`, never the library directly. |
| `Swinject DI container` | Manual init injection via `Coordinator` | Avoids a framework dependency; all dependencies visible at compile time. |

---

## 5. Data Flow

### Restaurant List Screen

Two awaits in the ViewModel — cache renders immediately, then network refreshes.

```
1. AppCoordinator reads User.lastUsedAddress from UserRepository (.cached)
2. RestaurantListViewModel.load()
     → isLoading = true

     // Phase 1 — cache (instant)
     if let cached = try? await FetchRestaurantsUseCase.execute(policy: .strict, param: FetchRestaurantsParam(addressID:))
         → RestaurantRepository checks RestaurantLocalDataSource only — throws on miss
         → ViewModel maps [Restaurant] → [RestaurantUIModel]
         → @Published restaurantList updated → UI renders immediately

     // Phase 2 — network (background)
     let fresh = try await FetchRestaurantsUseCase.execute(policy: .fresh, param: FetchRestaurantsParam(addressID:))
         → RestaurantRepository fetches RestaurantRemoteDataSource → GET /restaurants/<addressID>
         → DTO → Mapper → [Restaurant]
         → RestaurantLocalDataSource.save(dtos)         // Core Data updated
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
             → orderSSEDataSource.stream(orderID:)    // OrderSSEDataSourceProtocol in Domain/Interfaces/
             → returns AsyncStream<OrderSSEEventDTO>
             → for await event in stream → OrderMapper.toDomain(event) → Order
             → publishes Order via AnyPublisher<Order, AppError>
         → ViewModel.orderUpdates sink → maps Order → OrderUIModel
         → @Published courierLocation + orderStatus updated → map pin moves + label updates

OrderStatusViewController.viewDidDisappear()
     → OrderStatusViewModel.stopTracking()
         → OrderService.stopTracking()  ← closes SSE connection immediately
```

---

## 6. Technical Deep-dive

### Why SSE over polling?

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

### Why SSE over WebSockets?

| | SSE | WebSocket |
|---|---|---|
| Direction | Server → client only | Bidirectional |
| Protocol | HTTP/1.1 or HTTP/2 | ws:// (separate protocol) |
| Reconnection | Browser/client auto-reconnects | Manual |
| Use case | Courier tracking, notifications | Chat, collaborative editing |
| Complexity | Simple | Higher |

Courier tracking is read-only from the client's perspective — SSE is sufficient. WebSockets add bidirectional complexity that this scenario doesn't need.

### Why `AnyPublisher` over `AsyncStream` for `OrderService`?

`OrderService` is a Domain Service that lives alongside `@Published` Combine state in `OrderStatusViewModel`. `AnyPublisher<Order, AppError>` integrates natively with Combine operators — `debounce`, `throttle`, `receive(on: DispatchQueue.main)` — which are directly useful when SSE events arrive in rapid bursts (e.g. courier moving fast). `AsyncStream` would require bridging into Combine manually at the ViewModel boundary, and loses the operator pipeline. The choice is not about correctness — either works — but about consistency: the ViewModel is already Combine-based.

### Why is `OrderService` scoped to `OrderCoordinator`, not app-scoped?

Unlike `PlayerService` in the music streaming scenario (which must be app-scoped to keep audio playing when screens change), `OrderService` should only live as long as the Order Status screen is active.

**Why not app-scoped?** There is no reason to maintain an SSE connection when the user is not on the Order Status screen. Keeping it alive wastes battery and server resources.

**Why not ViewController-scoped?** If the ViewController is re-created (e.g. navigation stack manipulation), the service would be destroyed mid-stream. Coordinator ownership is the right granularity.

`OrderCoordinator` creates `OrderService` on init and the service is destroyed when the coordinator is deallocated — naturally closing the SSE connection.

### Why a server-hosted basket?

Basket state on the backend enables cross-device continuity — start an order on iPhone, continue on web or iPad. Trade-off: every basket mutation (`POST /basket`, `PATCH /basket`) requires a network round-trip. `BasketLocalDataSource` mirrors the server state in Core Data for two purposes:

1. **Instant restore** — if the app is killed and relaunched mid-basket, the local cache shows the last known state immediately while a `GET /basket` fetch runs in the background.
2. **Optimistic display** — after `PATCH /basket`, update the local cache immediately. Reconcile with the server response when it arrives.

`FetchPolicy.cached` on `FetchBasketUseCase` implements this: return local first, then refresh from network.

### Why UIKit throughout instead of SwiftUI?

The philosophy doc lists three UIKit triggers: scroll lifecycle control, `AVPlayer` integration, and direct UIKit-native view integration. This scenario hits two:

- Restaurant list and menu screens use `UITableView`/`UICollectionView` for `willDisplay cell` pagination hooks and sticky header customisation that SwiftUI's `List` does not expose at the same granularity.
- The Order Status screen embeds `OrderMapView` — a `UIView` subclass wrapping `MKMapView`. MapKit requires direct lifecycle control (setting the delegate, calling `setRegion`, adding/removing annotations) that is straightforward in UIKit and cumbersome through `UIViewRepresentable`.

SwiftUI would be valid for simpler screens (e.g. address picker), but the screens in scope justify UIKit throughout for consistency.

### Why `UIImageView` extension as the image loading facade?

SDWebImage and Kingfisher both provide their own `UIImageView` category. Calling the library's extension directly in every cell means swapping the library requires updating every call site. A single `UIImageView` extension that wraps whichever library is chosen means:

- The call site `imageView.setImage(url:)` is identical regardless of which library is underneath.
- Swapping SDWebImage for Kingfisher (or a native `URLSession`-based loader) touches one file.

This is the same isolation principle as `ThirdPartyDataSource` — the app calls the protocol, never the SDK directly.

### Why idempotency key on `CreateOrderParam`?

`POST /orders` is the highest-risk mutation. A network timeout on the client while the server succeeded creates a duplicate order. Generating `idempotencyKey: UUID()` at the `CreateOrderParam` call site (not inside the Repository or DataSource) ensures:

- The same request object carries the same key — retries re-use it automatically.
- If the server already created an order with that UUID, it returns the existing record rather than a duplicate.
- The key is not hidden inside the Repository — it is a first-class field on the param struct, visible to callers and tests.

### Interview Q&A

| Question | Answer |
|---|---|
| Why SSE over polling? | 1-second polling for 10 minutes = 600 HTTP requests, 599 return no new data. SSE holds one persistent connection; server writes only on state change. |
| Why SSE over WebSockets? | Courier tracking is server → client only. WebSockets add bidirectional complexity this scenario doesn't need. SSE is simpler and sufficient. |
| Why `AnyPublisher` for `OrderService` instead of `AsyncStream`? | `OrderService` sits in a Combine-based ViewModel. `AnyPublisher` integrates natively with debounce/throttle for burst events and `receive(on:)` for threading. `AsyncStream` would need manual Combine bridging at the ViewModel boundary. |
| Why is `OrderService` scoped to `OrderCoordinator`? | No reason to hold an SSE connection while the user is not tracking an order — wastes battery and server connections. ViewController scope is too narrow (re-creation destroys the service mid-stream). Coordinator is the right granularity. |
| Why server-hosted basket? | Cross-device continuity — same basket visible on iPhone and web. Local Core Data mirror provides instant UI restore and optimistic updates; backend is source of truth. |
| Why is `OrderSSEDataSourceProtocol` in `Domain/Interfaces/`? | `OrderService` is a Domain Service — it depends on the protocol, never the concrete. Domain defines the interface; Data provides the concrete `OrderSSEDataSource`. This is Dependency Inversion: Domain owns the contract, Data fulfils it. |
| Why not close SSE in `viewDidDisappear` directly? | The ViewController calls `OrderStatusViewModel.stopTracking()` → `OrderService.stopTracking()`. The ViewController never holds or knows about the Service — it goes through the ViewModel boundary. |
| Why no idempotency key on basket mutations? | `POST /basket` creates a basket at most once per user per restaurant; a duplicate add would be visible to the user and rejected by the server. `POST /orders` is the irreversible, high-stakes mutation — duplicates cause real business harm. Idempotency key effort is proportional to duplicate risk. |
| Why UIKit instead of SwiftUI for this scenario? | Two triggers from the philosophy doc: `UITableView`/`UICollectionView` scroll lifecycle for pagination, and `MKMapView` requiring direct lifecycle control in `OrderMapView`. SwiftUI `List` and `UIViewRepresentable` are valid but add friction where UIKit is the natural fit. |
