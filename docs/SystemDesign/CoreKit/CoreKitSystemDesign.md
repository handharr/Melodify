# CoreKit — System Design

CoreKit is a shared SPM local package. It contains networking and persistence primitives that every mini-app needs without carrying any domain knowledge. No app-specific types are imported here.

## 1. Requirements

### Functional
- Generic async/await HTTP client: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`
- Typed `APIError` propagation (`invalidURL`, `notFound`, `decodingFailed`, `networkError`, `conflict`)
- WebSocket client with channel multiplexing — one connection, many logical channels via `subscribe(channel:) → AsyncStream<String>`
- `LocalDataSourceProtocol` — generic protocol for any app's in-memory or disk-backed cache
- Image loading protocol stack: `ImageDataSourceProtocol` (fetch), `ImagePrefetcherProtocol` (prefetch)
- Analytics gateway protocol + two concrete implementations: console logging (dev) and no-op (test/preview)

### Non-Functional
- All public types are `Sendable` — safe to use across Swift concurrency contexts
- `WebSocketClient` is a Swift `actor` — all channel/continuation mutations are thread-safe without locks
- URLSession-based throughout — no third-party networking dependency
- No UIKit, no SwiftUI, no domain models — pure Foundation + Swift concurrency
- Public API is defined through protocols so every mini-app's Data layer can inject mocks in tests

---

## 2. Module API (Public Interface)

CoreKit has no HTTP endpoints — this section documents its public Swift API, which is the contract every mini-app's Data layer depends on.

### APIClient

```swift
public protocol APIClientProtocol: Sendable {
    func get<T: Decodable>(_ url: URL) async throws -> T
    func post<Body: Encodable & Sendable, T: Decodable>(_ url: URL, body: Body) async throws -> T
    func put<Body: Encodable & Sendable, T: Decodable>(_ url: URL, body: Body) async throws -> T
    func patch<Body: Encodable & Sendable, T: Decodable>(_ url: URL, body: Body) async throws -> T
    func delete<T: Decodable>(_ url: URL) async throws -> T
}
```

Concrete: `struct APIClient: APIClientProtocol` — URLSession-based, decodes with `JSONDecoder`, encodes bodies with `JSONEncoder`, maps 409 status to `APIError.conflict`.

### WebSocketClient

```swift
public protocol WebSocketClientProtocol: Sendable {
    func connect(to url: URL) async throws
    func disconnect() async
    func subscribe(channel: String) -> AsyncStream<String>
    func send(payload: String, channel: String) async throws
}
```

Concrete: `public actor WebSocketClient: WebSocketClientProtocol` — see Data Model Design for internals.

**Channel multiplexing:** The outer frame is a `WebSocketEnvelope { channel, payload }`. `ChannelRouter` (private actor) maps channel strings to `AsyncStream.Continuation` instances and routes incoming payloads to the correct subscriber.

### LocalDataSourceProtocol

```swift
public protocol LocalDataSourceProtocol {
    associatedtype Request
    associatedtype DTO: Codable

    func load(request: Request) -> DTO?
    func save(_ dto: DTO, for request: Request)
}
```

Each mini-app's concrete `LocalDataSource` implements this protocol.

### Image Loading

```swift
public protocol ImageDataSourceProtocol {
    func loadImage(from url: URL) async throws -> Data
}

public protocol ImagePrefetcherProtocol {
    func prefetch(urls: [URL])
    func cancelPrefetch(urls: [URL])
}
```

Concretes in CoreKit: `URLSessionImageDataSource` (URLSession download), `NoOpImagePrefetcher` (test/dev stub).  
`MusicApp/Data/` provides `ImageDataSource` (SDWebImage-backed) for production use — the protocol lets Data swap implementations without touching Domain.

### Analytics

```swift
public protocol AnalyticsEvent {
    var name: String { get }
    var params: [String: Any] { get }
}

public protocol AnalyticsGatewayProtocol {
    func track(event: any AnalyticsEvent)
}
```

Concretes:
- `ConsoleAnalyticsGateway` — prints event name + params to console (dev/debug)
- `NoOpAnalyticsGateway` — silently discards all events (test/preview)

---

## 3. Data Model Design

### Error Types

```swift
public enum APIError: Error, Sendable {
    case invalidURL
    case notFound
    case decodingFailed(Error)
    case networkError(Error)
    case conflict           // HTTP 409 — distinct from transient errors; needs domain-specific UX
}

public enum WebSocketError: Error, Sendable {
    case notConnected
    case encodingFailed
    case transportError(Error)
}
```

### WebSocket Envelope

```swift
// Wraps every WebSocket frame. The channel field routes the payload
// to the correct subscriber without the consumer knowing about other channels.
public struct WebSocketEnvelope: Codable, Sendable {
    public let channel: String
    public let payload: String   // JSON-encoded by the sender; opaque to the transport layer
}
```

---

## 4. High-Level Design

```
CoreKit/
├── Network/
│   ├── APIClient.swift          — struct APIClient: APIClientProtocol
│   │                              APIClientProtocol (public)
│   │                              APIError enum (public)
│   └── WebSocketClient.swift    — actor WebSocketClient: WebSocketClientProtocol
│                                  WebSocketClientProtocol (public)
│                                  WebSocketEnvelope (public)
│                                  ChannelRouter (private actor — internal to WebSocketClient)
│                                  WebSocketError (public)
├── Analytics/
│   ├── AnalyticsEvent.swift     — AnalyticsEvent protocol (public)
│   ├── AnalyticsGatewayProtocol.swift
│   ├── ConsoleAnalyticsGateway.swift
│   └── NoOpAnalyticsGateway.swift
├── ImageLoading/
│   ├── ImageDataSourceProtocol.swift
│   ├── ImagePrefetcherProtocol.swift
│   ├── URLSessionImageDataSource.swift
│   └── NoOpImagePrefetcher.swift
└── Persistence/
    └── LocalDataSourceProtocol.swift
```

**Dependency graph within CoreKit**

- All public protocols (`APIClientProtocol`, `WebSocketClientProtocol`, `LocalDataSourceProtocol`, `AnalyticsGatewayProtocol`, `ImageDataSourceProtocol`, `ImagePrefetcherProtocol`) are independent — no cross-module coupling inside CoreKit itself.
- `WebSocketClient` is the only type with internal complexity (`ChannelRouter`); everything else is a straightforward protocol + one or two concretes.

**Who imports CoreKit?**

| Module | Imports CoreKit? | Why |
|---|---|---|
| MusicApp/Data | Yes | Uses `APIClient`, `LocalDataSourceProtocol`, `ImageDataSourceProtocol` |
| ChatApp/Data | Yes | Uses `APIClient`, `WebSocketClient`, `AnalyticsGatewayProtocol` |
| MusicApp/Domain | No | Domain never imports CoreKit |
| ChatApp/Domain | No | Domain never imports CoreKit |
| MelodifyDesignSystem | No | UI library — no networking |
| Host app (Melodify) | Yes | Wires `WebSocketClient` and `ConsoleAnalyticsGateway` at app start |

---

## 5. Data Flow

### HTTP request lifecycle

```
MusicApp: TrackRemoteDataSource.searchTracks(request:)
  → build URL from URLComponents (term, media, limit, offset params)
  → APIClient.get<iTunesSearchResponse>(url)
      → URLRequest(url: url) → URLSession.data(for:)
      → check HTTP status (409 → APIError.conflict)
      → JSONDecoder.decode(iTunesSearchResponse.self, from: data) → response.results: [TrackDTO]
  → return [TrackDTO] to TrackRepository
```

### WebSocket receive lifecycle

```
WebSocketClient.connect(to: url)
  → URLSession.webSocketTask(with: url).resume()
  → receiveLoop(task:) starts in a Task

Incoming frame arrives:
  → task.receive() → .string(text)
  → decode WebSocketEnvelope (channel: "conv-abc", payload: "{...}")
  → ChannelRouter.yield(payload, to: "conv-abc")
  → "conv-abc" continuation.yield(payload)
  → MessageRepository for conv-abc receives raw JSON string
  → decode ChatEventDTO → process event

On disconnect or error:
  → ChannelRouter.cancelAll()  → all continuations finish → all AsyncStreams terminate
```

### Channel subscription lifecycle

```
ChatViewModel.start()
  → StreamMessagesUseCase.execute("conv-abc")
      → MessageRepository.messages("conv-abc")
          → WebSocketClient.subscribe(channel: "conv-abc")
              → AsyncStream { continuation in
                    Task { await router.add(continuation, for: "conv-abc") }
                    continuation.onTermination = { _ in
                        Task { await self.router.remove(channel: "conv-abc") }
                    }
                }

ViewController deinit / ViewModel cancels task
  → continuation.onTermination fires
  → ChannelRouter.remove("conv-abc")
  → slot is released; no memory leak
```

### Analytics event flow

```
User action in MusicApp
  → MusicAnalyticsEvent.searchPerformed(term:)  // conforms to AnalyticsEvent
  → AnalyticsGatewayProtocol.track(event:)
      [dev]  ConsoleAnalyticsGateway → print("[\(event.name)] \(event.params)")
      [test] NoOpAnalyticsGateway   → (silently discarded)
```

---

## 6. Technical Deep-dive

### Why `WebSocketClient` is a Swift actor, not a class with a lock?

`WebSocketClient` mutates a `ChannelRouter` that maps channel strings to `AsyncStream.Continuation` instances. Those continuations can be added or removed from any concurrency context — the receive loop, a subscription call, or a disconnect. An actor serialises all of that automatically. A class with `NSLock` would work but requires manual discipline: forget to lock in one path and you get a data race. The actor is the compiler-enforced option.

### Why `ChannelRouter` is a separate private actor, not part of `WebSocketClient`?

Keeping `ChannelRouter` private and separate from the public `WebSocketClient` actor enforces a single responsibility boundary. `WebSocketClient` owns the transport (connect, disconnect, receive loop). `ChannelRouter` owns the routing table. Neither needs to know the internals of the other. It also avoids actor reentrancy issues — a call to `yield` on `ChannelRouter` from within `WebSocketClient`'s receive loop does not re-enter the client actor.

### Why `LocalDataSourceProtocol` uses `associatedtype` instead of a generic parameter?

A generic parameter `LocalDataSource<DTO>` would require every caller to spell out the full generic type at every injection point. An `associatedtype` lets each concrete type (`TrackLocalDataSource`, `MessageLocalDataSource`) declare its own `DTO` and `Request` types — the call site stays clean and there is no generics explosion through the dependency graph. The trade-off is that `LocalDataSourceProtocol` cannot be used as an existential directly; it's always consumed through a concrete type or a type-erased wrapper, which is the correct usage pattern in a DI composition root.

### Why URLSession only — no third-party networking library?

CoreKit is a shared primitive layer consumed by all mini-apps. Adding Alamofire or Moya would: (1) impose a version constraint on every app that imports CoreKit, (2) add build-time overhead for functionality URLSession already provides, and (3) couple the shared layer to a third party that could be abandoned or break on a Swift/Xcode update. URLSession with `async/await` and `JSONDecoder` covers everything CoreKit needs.

### Why are analytics event concretes (e.g. `MusicAnalyticsEvent`) in each mini-app, not in CoreKit?

`AnalyticsGatewayProtocol` and `AnalyticsEvent` belong in CoreKit because every app needs to track events. But the event *values* (`searchPerformed`, `trackPlayed`) are domain-specific — they know about tracks, playlists, conversations. Domain knowledge has no place in CoreKit. Each mini-app defines its own enum conforming to `AnalyticsEvent`; CoreKit provides only the protocol and the concrete gateway implementations (`ConsoleAnalyticsGateway`, `NoOpAnalyticsGateway`).

### Why no UIKit or SwiftUI in CoreKit?

CoreKit is consumed by the Data layer of every mini-app. The Data layer must not import UIKit or SwiftUI — domain and data layers are framework-agnostic by design. If CoreKit imported UIKit, every SPM target that imports CoreKit would transitively pull in UIKit, breaking the layer rule. Pure Foundation + Swift Concurrency keeps CoreKit importable from any layer.

### Interview Q&A

| Question | Answer |
|---|---|
| Why is `WebSocketClient` an actor? | Continuations are mutated from multiple contexts — receive loop, subscriptions, disconnects. Actor serialises all access without manual locking. |
| Why `associatedtype` on `LocalDataSourceProtocol`? | Avoids generic parameter explosion at call sites. Each concrete type declares its own DTO/Request pair; the DI composition root wires the right concrete. |
| What prevents two apps from interfering on the same WebSocket connection? | `ChannelRouter` namespaces each subscriber by its channel string. A message for `"conv-abc"` is only delivered to the subscriber for that channel, never to unrelated subscribers. |
| Why no third-party networking? | URLSession + async/await covers all needs. A third-party dependency in a shared package constrains every app that imports it. |
