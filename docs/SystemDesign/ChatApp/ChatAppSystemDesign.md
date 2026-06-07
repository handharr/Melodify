# ChatApp — System Design

## 1. Requirements

### Functional
- List all conversations with avatar (initials), last message preview, timestamp, and unread badge
- Open a conversation and view full message history — cursor-paginated (load older messages on scroll)
- Send text messages via HTTP POST (not WebSocket — outbound is intentionally HTTP)
- Receive real-time messages via WebSocket, multiplexed by conversation channel
- Offline send queue: if a send fails due to network loss, persist the message locally; retry automatically on next app foreground or APNs silent push wake
- Heterogeneous message types: `text`, `image`, `audio`, `deleted` — exhaustive handling at compile time via enum
- Mark conversation as read; unread count synced across devices via WebSocket `conversation.unread_updated` event
- Reconnect WebSocket automatically after drop; fetch missed messages via HTTP before re-attaching to stream

### Non-Functional
- One shared `WebSocketClient` connection (CoreKit); per-conversation channels via `subscribe(channel: "conv-{id}")` — O(1) connections per user, not O(conversations)
- WebSocket is receive-only for inbound events; HTTP POST is the outbound path
- `sequence: Int` on every `MessageDTO` — server-assigned, monotonic per conversation; used for ordering and gap detection on reconnect
- Idempotency key (`clientId` UUID) on every send — safe retry without duplicates
- `PendingMessageQueue`: Swift actor, persisted to `Documents/pending_messages.json`, indexed by `conversationId` — flush is O(pending conversations), not O(all conversations)
- Flush triggered by `UIApplication.didBecomeActiveNotification` in `ChatCoordinator`, APNs silent push, and `BGAppRefreshTask` — not in any ViewController
- `MessageLocalDataSource` backed by Core Data; `NSFetchRequest` with `fetchBatchSize: 50` for cursor-paginated reads
- `WebSocketClient` (CoreKit) internally handles reconnect with exponential backoff (1s → 2s → … → 60s cap) and exposes `connectionState: AsyncStream<ConnectionState>`; `MessageRepository` observes it — on `.connected` after `.disconnected`, fires catch-up fetch (`?after=seqN`) before re-attaching to stream
- WebSocket `AsyncStream` buffer policy: `.bufferingOldest(256)` — keeps oldest frames under pressure; burst catch-up goes through HTTP, not the stream
- `@MainActor` on all ViewModels; `defer { isLoading = false }` on every async path

---

## 2. API Design

### WebSocket (inbound events only)

**Connection:** `wss://<server>/ws`  
**Channel subscription:** `"conv-{conversationId}"` (e.g. `"conv-abc-123"`)

The outer envelope is handled by `CoreKit.WebSocketClient`:

```json
{
  "channel": "conv-abc-123",
  "payload": "<JSON-encoded ChatEventDTO>"
}
```

**ChatEventDTO** (inner payload after channel routing)

```json
{
  "type": "message.new",
  "message": { /* MessageDTO */ },
  "conversation_id": "conv-abc-123",
  "unread_count": 4
}
```

| Event type | Meaning |
|---|---|
| `message.new` | New message received — append to list |
| `message.updated` | Message content changed (edit, status update) |
| `message.deleted` | Message removed — remove from list |
| `conversation.unread_updated` | Unread count changed (e.g. read on another device) — update badge |

### HTTP (outbound send, history fetch, mark-read)

| Action | Method | Endpoint | Body / Params | Implementation status |
|---|---|---|---|---|
| Fetch latest messages | GET | `/api/v1/conversations/{id}/messages?limit={n}` | — | **Stub** — local mock JSON covers the demo |
| Fetch older messages (pagination) | GET | `/api/v1/conversations/{id}/messages?before={messageId}&limit={n}` | — | **Stub** |
| Reconnect catch-up | GET | `/api/v1/conversations/{id}/messages?after={seq}` | — | **Stub** |
| Send message | POST | `/api/v1/conversations/{id}/messages` | see below | **Stub** — synthesises a local response |
| Mark conversation read | POST | `/api/v1/conversations/{id}/read` | — | **Stub** |

**Send message request body** (current implementation — text-only)

```json
{
  "client_id": "uuid-v4",
  "type": "text",
  "text": "Hello there"
}
```

`client_id` is the idempotency key — if the server already has a message with this UUID it returns the existing record rather than creating a duplicate.

**Full production body** (target shape when image/audio sending is implemented)

```json
{
  "client_id": "uuid-v4",
  "type": "text | image | audio",
  "text": "Hello there",
  "image_url": "https://...",
  "audio_url": "https://...",
  "audio_duration": 12.5,
  "aspect_ratio": 1.78
}
```

**Send message response** — server returns the confirmed `MessageDTO` with `status: "sent"` and the server-assigned `sequence`.

> `MessageRemoteDataSource` currently synthesises a local response (no live server). The struct types and interface contract match exactly what a real server would expect.

---

## 3. Data Model Design

### Domain Models

```swift
struct Conversation: Sendable, Equatable {
    let id: String
    let participantIds: [String]
    let participantNames: [String: String]   // userId → display name
    let lastMessage: String
    let lastMessageAt: Date
    let unreadCount: Int
}

struct Message: Sendable, Equatable {
    let id: String
    let conversationId: String
    let senderId: String
    let content: MessageContent
    let status: MessageStatus
    let sequence: Int        // server-assigned, monotonic per conversation
    let createdAt: Date
}

// No optionals for content type — illegal states unrepresentable.
enum MessageContent: Sendable, Equatable {
    case text(String)
    case image(URL, aspectRatio: CGFloat)
    case audio(duration: TimeInterval, url: URL)
    case deleted
}

enum MessageStatus: String, Codable, Sendable, Equatable {
    case pending    // locally queued, not yet sent
    case sent       // server acknowledged
    case delivered  // delivered to recipient device
    case read       // recipient opened the conversation
}
```

### DTOs (Codable, mirror wire format)

```swift
// Wire format optionals reflect API shape — Mapper decides what's valid
struct MessageDTO: Codable, Sendable {
    let id: String
    let conversationId: String       // "conversation_id"
    let senderId: String             // "sender_id"
    let sequence: Int                // server-assigned monotonic sequence per conversation
    let type: String                 // "text" | "image" | "audio" | "deleted"
    let text: String?
    let imageURL: String?            // "image_url"
    let aspectRatio: CGFloat?        // "aspect_ratio"
    let audioDuration: TimeInterval? // "audio_duration"
    let audioURL: String?            // "audio_url"
    let createdAt: String            // "created_at" — ISO8601
    let status: String               // "pending" | "sent" | "delivered" | "read"
}

struct ConversationDTO: Codable, Sendable {
    let id: String
    let participantIds: [String]           // "participant_ids"
    let participantNames: [String: String] // "participant_names"
    let lastMessage: String                // "last_message"
    let lastMessageAt: String             // "last_message_at" — ISO8601
    let unreadCount: Int                   // "unread_count"
}

// Inner payload after WebSocket channel routing
struct ChatEventDTO: Codable, Sendable {
    let type: String                 // ChatEventType raw value
    let message: MessageDTO?
    let conversationId: String?      // "conversation_id" — present on unread_updated
    let unreadCount: Int?            // "unread_count" — present on unread_updated
}

enum ChatEventType: String, Codable {
    case messageNew     = "message.new"
    case messageUpdated = "message.updated"
    case messageDeleted = "message.deleted"
    case unreadUpdated  = "conversation.unread_updated"
}
```

### Request types (Domain inputs — `Request<Query, Path>`)

```swift
// query.userId scopes the list to the current user's conversations
struct FetchConversationsQuery: Sendable, Equatable { let userId: String }
typealias FetchConversationsRequest = Request<FetchConversationsQuery, Void>

// path carries cursor fields — nil beforeMessageId loads the latest page
struct FetchMessagesPath: Sendable, Equatable {
    let conversationId: String
    let beforeMessageId: String?  // cursor — nil = load latest page
    let limit: Int                // default 50
}
typealias FetchMessagesRequest = Request<Void, FetchMessagesPath>

// Not a Request<Query,Path> — send is a mutation; FetchPolicy doesn't apply.
struct SendMessageRequest: Sendable {
    let conversationId: String
    let content: MessageContent
    let clientId: String          // UUID().uuidString — generated in init
}

// Mark-read — no body, no response payload needed beyond success/failure
struct MarkReadPath: Sendable, Equatable { let conversationId: String }
typealias MarkReadRequest = Request<Void, MarkReadPath>
```

### PendingMessageDTO (offline queue persistence)

```swift
// Persisted offline queue entry — structurally mirrors MessageDTO content fields
struct PendingMessageDTO: Codable, Sendable {
    let id: String            // clientId — doubles as idempotency key on retry
    let conversationId: String
    let type: String
    let text: String?
    let imageURL: String?
    let aspectRatio: CGFloat?
    let audioDuration: TimeInterval?
    let audioURL: String?
    let queuedAt: String      // ISO8601
}
```

---

## 4. High-Level Design

```
┌─────────────────────────────────────────────────────────────────────┐
│  Presentation  (UIKit · Combine)                                    │
│  ConversationListViewController / ConversationListViewModel         │
│  ChatViewController / ChatViewModel                                 │
│  Cells: TextMessageCell, AudioMessageCell,                          │
│         ImageMessageCell, DeletedMessageCell                        │
│  (UICollectionView with heterogeneous registration)                 │
└────────────────────────────┬────────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────────┐
│  Domain                                                             │
│  FetchConversationsUseCase   → ConversationRepositoryProtocol       │
│  ObserveMessagesUseCase      → MessageRepositoryProtocol            │
│    (FRC-backed; yields initial page + every Core Data write)        │
│  FetchMessagesUseCase        → MessageRepositoryProtocol            │
│    (cursor pagination only — writes to Core Data; FRC re-yields)    │
│  SendMessageUseCase          → MessageRepositoryProtocol            │
│  FlushPendingMessagesUseCase → MessageRepositoryProtocol            │
│  MarkReadUseCase             → ConversationRepositoryProtocol       │
└────────────────────────────┬────────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────────┐
│  Data                                                               │
│  ConversationRepository      → ConversationLocalDataSource          │
│  ConversationLocalDataSource                  [bundled JSON mock]   │
│  MessageRepository           → MessageRemoteDataSource              │
│                              → MessageLocalDataSource               │
│                              → WebSocketClientProtocol              │
│                              → PendingMessageQueue                  │
│    observes WebSocketClient.connectionState → triggers catch-up     │
│  MessageRemoteDataSource              [CoreKit · APIClient]         │
│  MessageLocalDataSource               [CoreData · NSFetchedResultsController] │
│  PendingMessageQueue (actor)          [Foundation · FileManager]    │
│  Mappers: ConversationMapper, MessageMapper                         │
└────────────────────────────┬────────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────────┐
│  Application                                                        │
│  ChatCoordinator              [UIKit · BackgroundTasks ·            │
│                                UserNotifications]                   │
│    • didBecomeActiveNotification → FlushPendingMessages             │
│    • APNs silent push            → FlushPendingMessages             │
│    • BGAppRefreshTask            → periodic catch-up flush          │
└────────────────────────────┬────────────────────────────────────────┘
                             │ imports
┌────────────────────────────▼────────────────────────────────────────┐
│  Dependencies                                                       │
│  CoreKit             WebSocketClient (reconnect + NWPathMonitor      │
│                        internal) · APIClient · ChannelRouter        │
│  CoreData            NSPersistentContainer · NSFetchRequest         │
│  BackgroundTasks     BGTaskScheduler · BGAppRefreshTask             │
│  UserNotifications   APNs silent push handling                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Navigation (Coordinator pattern)**

```
ChatCoordinator (composition root + flush orchestrator)
  └── ConversationListViewController
        └── ChatViewController (pushed on conversation tap)
```

`ChatCoordinator` is injected with `WebSocketClientProtocol` by the host app. It handles three flush triggers — `didBecomeActiveNotification`, APNs silent push, and `BGAppRefreshTask` — all routing to the same `FlushPendingMessagesUseCase`. Reconnection is internal to `WebSocketClient` — the coordinator does not manage it. `MessageRepository` observes `WebSocketClient.connectionState` and fires the catch-up fetch on `.connected` after a drop.

---

## 5. Data Flow

### Message observation (open a conversation)

```
ChatViewController.viewDidLoad()
  → ChatViewModel.start()
      → ObserveMessagesUseCase.execute(conversationId: "conv-abc")
          → MessageRepository.observe(conversationId: "conv-abc")
              → MessageLocalDataSource.observe(conversationId:)
                  → NSFetchedResultsController:
                        predicate:        conversationId == "conv-abc"
                        sortDescriptors:  [sequence ASC]
                        fetchBatchSize:   50   // lazy faulting — no full load into memory
                  → performFetch()
                  → continuation.yield(frc.fetchedObjects → MessageMapper.toDomain)
                        // View renders all locally cached messages instantly

              [runs indefinitely — WebSocket writes to Core Data → FRC fires]
              → WebSocketClient.subscribe(channel: "conv-abc")
                  // AsyncStream buffer: .bufferingOldest(256)
                  for await payload in AsyncStream<String>:
                      decode ChatEventDTO → switch ChatEventType:
                        .messageNew     → MessageLocalDataSource.save(dto)    // Core Data insert
                        .messageDeleted → MessageLocalDataSource.delete(id:)  // Core Data delete
                        .unreadUpdated  → (handled by ConversationListViewModel, not here)
                        // NSFetchedResultsController.controllerDidChangeContent fires
                        // → continuation.yield(frc.fetchedObjects → MessageMapper.toDomain)
                        // No manual accumulation — Core Data is the single source of truth
```

### Load older messages (pagination)

```
User scrolls to top of ChatViewController
  → ChatViewModel.loadMore()
      → FetchMessagesUseCase.execute(
            FetchMessagesRequest(path: .init(
                conversationId: "conv-abc",
                beforeMessageId: oldestLoadedId,
                limit: 50
            ))
        )
          → MessageRepository.fetchOlder(conversationId:, before: oldestLoadedId, limit: 50)
              → MessageRemoteDataSource.fetchMessages(conversationId:, before:, limit:)
                  → GET /api/v1/conversations/{id}/messages?before={messageId}&limit=50
              → MessageLocalDataSource.save(dtos)   // write batch to Core Data
              // NSFetchedResultsController detects batch insert
              // → controllerDidChangeContent fires
              // → ObserveMessagesUseCase stream yields expanded [Message] list
              // ViewModel preserves scroll position (oldestLoadedId bookmark)
```

### Reconnect + catch-up (WebSocket drop)

```
WebSocket drops
  → WebSocketClient (CoreKit, internal)
      NWPathMonitor detects .satisfied
      exponential backoff: retryDelay 1s → 2s → 4s → ... → 60s cap
      WebSocketClient.connect() succeeds → connectionState yields .connected

MessageRepository observes WebSocketClient.connectionState
  → .connected (after prior .disconnected)
      → GET /api/v1/conversations/{id}/messages?after={lastKnownSequence}
      → save batch → MessageLocalDataSource (Core Data)
      → NSFetchedResultsController fires → ObserveMessagesUseCase stream yields
      → re-attach WebSocketClient.subscribe(channel: "conv-abc")
```

Reconnect logic is entirely inside `WebSocketClient` — no separate component, no "Manager". `MessageRepository` is a passive observer of connection state; it reacts but does not drive reconnection.

### Send message

```
User taps Send, enters "Hello there"
  → ChatViewModel.send(text: "Hello there")
      → SendMessageUseCase.execute(
            SendMessageRequest(conversationId: "conv-abc", content: .text("Hello there"))
            // clientId = UUID().uuidString generated inside SendMessageRequest.init
        )
          → MessageRepository.send(request:)
              → SendMessageAPIRequest(from: request)   // { client_id, type: "text", text }
              → POST /api/v1/conversations/{id}/messages
              [success]
                  → MessageDTO (status: "sent", sequence: N) → localDataSource.save(dto)
                  → MessageMapper.toDomain → Message
                  → returns Message to ViewModel → View updates
              [failure — network loss]
                  → PendingMessageDTO(id: request.clientId, ...) → PendingMessageQueue.enqueue
                  → throw ChatError.messageQueued
      → ViewModel: catches .messageQueued → shows message with .pending status indicator
```

### Mark conversation read

```
User opens ChatViewController
  → ChatViewModel.markRead()
      → MarkReadUseCase.execute(MarkReadRequest(path: .init(conversationId: "conv-abc")))
          → POST /api/v1/conversations/{id}/read
          → server resets unread counter, broadcasts:
              { "type": "conversation.unread_updated", "conversation_id": "conv-abc", "unread_count": 0 }

WebSocket stream (ConversationListViewModel subscribes)
  → ChatEventType.unreadUpdated
      → update local Conversation.unreadCount = 0
      → ConversationListViewModel publishes updated list → badge clears
```

### Offline flush (on app foreground / APNs / BGAppRefreshTask)

```
Trigger: didBecomeActiveNotification | APNs silent push | BGAppRefreshTask
  → ChatCoordinator.flushAllPendingMessages()
      → PendingMessageQueue.pendingConversationIds()   // O(pending) — only convs with queue
      for each conversationId in pendingIds:
          → FlushPendingMessagesUseCase.execute(conversationId:)
              → MessageRepository.flushPending(conversationId:)
                  → PendingMessageQueue.dequeue(conversationId:) → [PendingMessageDTO]
                  for each pending:
                      → SendMessageAPIRequest(from: pending) → POST (same clientId = idempotency key)
                      [success] → localDataSource.save(dto) → message shows as .sent
                      [failure] → PendingMessageQueue.enqueue(pending)  // retry next trigger
```

---

## 6. Technical Deep-dive

### Why HTTP POST for outbound, not WebSocket?

WebSocket is a transport — it has no delivery semantics. If you send a message over WebSocket and the frame is dropped, you get no error. HTTP POST gives you: a status code (200 sent, 409 conflict, 5xx retry), a request body you can log and replay, and a confirmed response with the server-assigned message ID and sequence number. The idempotency key (`clientId`) only works over a request/response protocol. The split is intentional: WebSocket for inbound real-time events, HTTP for outbound actions that need a result.

### Why one WebSocket connection instead of one per conversation?

One socket per conversation is O(conversations) connections per user. A user with 50 open conversations would hold 50 persistent TCP connections — unsustainable on server and mobile battery. One shared `WebSocketClient` with channel multiplexing is O(1) per user. The `ChannelRouter` actor maps channel strings to continuations; subscribing to a new conversation adds one entry to the router's dictionary, not a new socket.

```
Single WebSocketClient (CoreKit actor)
  └── One URLSessionWebSocketTask to wss://<server>/ws
  └── ChannelRouter (private actor)
        ├── "conv-abc" → AsyncStream.Continuation → MessageRepository (conv-abc)
        ├── "conv-xyz" → AsyncStream.Continuation → MessageRepository (conv-xyz)
        └── ...

Incoming frame: { "channel": "conv-abc", "payload": "{...}" }
  → WebSocketClient.receiveLoop decodes WebSocketEnvelope
  → ChannelRouter.yield(payload, to: "conv-abc")
  → conv-abc subscriber's AsyncStream yields the raw payload string
```

### Why `MessageContent` enum instead of optional fields?

Optional fields (`text: String?`, `imageURL: URL?`) make invalid states representable at the type level. A `MessageDTO` with no text and no image URL is syntactically valid Swift but semantically illegal in the domain. The `MessageContent` enum makes illegal states unrepresentable: every `Message` has exactly one content case. The switch in the cell factory is exhaustive at compile time — adding a new message type without handling it is a build error, not a runtime crash.

### Why `sequence: Int` on every `MessageDTO`?

WebSocket frames can arrive out of order across reconnects and burst deliveries. Without a server-assigned sequence number, the client has no way to detect gaps or determine ordering. `sequence` unlocks three behaviours simultaneously:

1. **Ordering** — accumulator is sorted by `sequence`, not arrival time
2. **Gap detection** — a jump in sequence (e.g. 14 → 17) means frames 15–16 were lost; trigger a catch-up fetch
3. **Reconnect catch-up** — `GET ?after=lastKnownSeq` returns only the missed window; no full reload

The sequence number lives in `MessageDTO` (Data layer), not in `Message` (Domain). Domain only cares about ordering, which is already expressed via `createdAt`. The sequence is a transport concern — it travels through Mapper but isn't part of domain logic.

### Why reconnect logic lives inside `WebSocketClient`, not a separate component?

Reconnection is not a separate architectural concern — it is an internal behaviour of the WebSocket client. `WebSocketClient` wraps `URLSessionWebSocketTask`; maintaining that connection (including recovering from a drop) is the client's own responsibility.

A separate "ConnectionManager" (the naming pattern the architecture explicitly bans) would mean: the caller must know that the client can drop, must trigger reconnection manually, and must know when it's safe to re-subscribe. That leaks transport-level knowledge into the Data or Application layer. The client should be self-healing — callers subscribe to a channel and trust the client to keep the connection alive.

```swift
// CoreKit — internals invisible to callers
actor WebSocketClient: WebSocketClientProtocol {
    // Exposed to callers
    var connectionState: AsyncStream<ConnectionState>   // .connected / .disconnected / .reconnecting
    func subscribe(channel: String) -> AsyncStream<String>

    // Internal — callers never touch these
    private var retryDelay: TimeInterval = 1.0
    private let maxDelay: TimeInterval = 60.0
    private var pathMonitor: NWPathMonitor

    private func reconnectLoop() async {
        // NWPathMonitor detects .satisfied → retry connect() with backoff
        // yields .reconnecting → .connected on success
    }
}
```

`MessageRepository` observes `connectionState`. On `.connected` after `.disconnected`, it fires the catch-up fetch — this is the repository's response to a domain event (connection restored), not transport management. The boundary is clean: client owns the connection, repository owns the data consistency.

### Why two use cases for messages — `ObserveMessagesUseCase` and `FetchMessagesUseCase` — instead of one?

They have different execution models. That is the only justification needed, and it is sufficient.

```swift
// ObserveMessagesUseCase — never completes
func execute(conversationId: String) -> AsyncStream<[Message]>

// FetchMessagesUseCase — one-shot, throws on failure
func execute(_ request: FetchMessagesRequest) async throws
```

Their signatures on `MessageRepositoryProtocol` are different types — one is a continuous stream, the other is a throwing async function. You cannot merge them without giving a single use case two modes of operation, which breaks single responsibility.

| | `ObserveMessagesUseCase` | `FetchMessagesUseCase` |
|---|---|---|
| Trigger | `viewDidLoad` — once | User scrolls to top — on demand |
| Lifetime | Alive until screen dismissal | Completes immediately |
| Return type | `AsyncStream<[Message]>` | `Void` (FRC delivers the result) |
| Failure path | No throws — stream stays open | `throws` — show error, allow retry |

They cooperate but do not overlap. `FetchMessagesUseCase` writes older messages to Core Data; `ObserveMessagesUseCase`'s FRC detects the batch insert and re-yields. The ViewModel calls both, for entirely different reasons.

**If challenged: "could you merge them?"** Yes — some architectures pass a "load more" signal into the stream (a `PassthroughSubject<Void, Never>` that triggers a fetch). But that makes the stream bidirectional: the caller both reads from it and pushes commands into it. Unidirectional data flow is gone, and the combined use case is harder to test and harder to explain. Two simple use cases with clear contracts are the better trade-off.

### Why `ObserveMessagesUseCase` instead of `StreamMessagesUseCase`?

`StreamMessagesUseCase` implied the stream came from WebSocket — an implementation detail that leaked into the domain. The domain doesn't know or care where updates come from. It knows that a conversation has a live, observable message list.

With `NSFetchedResultsController` as the stream source, the correct domain name is `ObserveMessagesUseCase` — it observes a resource, same as you would observe any other piece of state. The WebSocket is an invisible write path into Core Data; the FRC is the read path. The use case name reflects the domain intent, not the transport.

The rename also removes the question "why do we have both `StreamMessagesUseCase` and `FetchMessagesUseCase`?" Their roles are now unambiguous:

| Use case | Role |
|---|---|
| `ObserveMessagesUseCase` | Live observation — FRC-backed `AsyncStream<[Message]>`; yields initial cache + every Core Data write |
| `FetchMessagesUseCase` | Cursor pagination — one-shot remote fetch; writes to Core Data; FRC re-yields automatically |

`FetchMessagesUseCase` no longer returns messages to the ViewModel. It just triggers the remote fetch and Core Data write. The observation stream handles delivery.

### Why Core Data as single source of truth (no in-memory accumulation)?

The original design maintained an in-memory `accumulated: [MessageDTO]` array inside `MessageRepository` and yielded it on each WebSocket event. Core Data was written to for persistence but never read back as the live source.

The problem: if the app is killed mid-conversation and relaunched, the accumulated array is gone. The ViewModel re-fetches from Core Data — but if the two sources diverged (a save failed, a delete was missed), the displayed state is inconsistent with what was persisted.

With `NSFetchedResultsController` as the stream source, there is no dual state:
- Every write (WebSocket event, pagination fetch, send confirmation) goes to Core Data
- Every read comes from Core Data via FRC
- `continuation.yield` is called only from `controllerDidChangeContent` — the ViewModel always sees what Core Data holds

```
WebSocket event → Core Data write → FRC fires → AsyncStream yields → ViewModel updates
Pagination fetch → Core Data write → FRC fires → AsyncStream yields → ViewModel updates
Send confirm    → Core Data write → FRC fires → AsyncStream yields → ViewModel updates
```

One write path. One read path. One truth.

### Why cursor pagination protocol is defined now, even with a mock backend?

The protocol contract is what every caller depends on — `ChatViewModel`, `FetchMessagesUseCase`, and `MessageRepositoryProtocol`. Defining `before: String?, limit: Int` now means the call sites are already correct when Core Data replaces the in-memory store. Adding pagination later to a protocol that only exposes `messages(conversationId:)` requires simultaneous changes across all four layers — a much larger change surface.

```swift
// Defined now — mock impl ignores before/limit; Core Data impl uses both
func messages(
    conversationId: String,
    before messageId: String?,
    limit: Int
) async throws -> [MessageDTO]
```

### Why two-path for burst delivery: stream vs catch-up HTTP?

The WebSocket stream is designed for low-latency, low-volume real-time events (a few messages per second). Catch-up after reconnect can be high-volume (hundreds of messages in a burst). Routing catch-up through the stream exhausts the `AsyncStream` buffer and risks dropping frames under `.bufferingOldest(256)`.

The correct split: catch-up via `GET ?after=seqN` (paginated, retryable HTTP), real-time via stream (low-latency delivery of current events). The stream buffer is never responsible for history.

### Why Core Data over Realm for `MessageLocalDataSource`?

Chat message storage is **append-heavy, cursor-read**. Core Data fits this pattern directly:

- `NSFetchRequest` with `sequence < beforeSeq` predicate + `fetchBatchSize: 50` gives cursor pagination with lazy faulting — no full load into memory
- Background context (`NSPersistentContainer.performBackgroundTask`) wraps cleanly inside a Swift actor — no threading ceremony
- `NSFetchedResultsController` fires `controllerDidChangeContent` on insert — reactive updates without a separate observation mechanism
- No third-party dependency

Realm's strength is **live `Results<T>`** — lazily evaluated queries that stay up to date as the store changes. That pattern fits FeedApp (read-heavy, background-sync-driven, heterogeneous items). For ChatApp, live queries add complexity without benefit: new messages arrive from the WebSocket stream (`AsyncStream<[Message]>`), not from a background Realm write. Realm objects are also not `Sendable` — passing them across an actor boundary requires `.freeze()` + copy, which erases the live-object advantage entirely.

Realm is the right choice for FeedApp. Core Data is the right choice for ChatApp.

### Why `PendingMessageQueue` is indexed by `conversationId`?

A flat array forces `FlushPendingMessagesUseCase` to scan all conversations on every flush — including conversations with zero pending messages. Indexing by `conversationId` at enqueue time makes flush O(pending conversations):

```swift
actor PendingMessageQueue {
    private var queue: [String: [PendingMessageDTO]] = [:]  // conversationId → pending

    func pendingConversationIds() -> [String] { Array(queue.keys) }

    func dequeue(conversationId: String) -> [PendingMessageDTO] {
        defer { queue[conversationId] = nil }
        return queue[conversationId] ?? []
    }
}
```

If zero conversations have pending messages, `pendingConversationIds()` returns `[]` and the flush is a no-op — no disk access, no network calls.

### Why `clientId` generated in `SendMessageRequest.init`?

If generated at the ViewModel call site, the same action (e.g. a button tap that retries) would produce different UUIDs each time — defeating idempotency. If generated in the Repository or DataSource, the key is not accessible to the offline queue. Generating it in `SendMessageRequest.init` means: the same `Request` object always carries the same `clientId`, the queue can persist it, and retries (whether from queue flush or network retry) re-use the same key. The server deduplicates on `client_id` — safe to call twice with the same UUID.

### Why flush is triggered in `ChatCoordinator`, not in a ViewController?

`UIApplication.didBecomeActiveNotification` fires app-wide — it doesn't belong to any one screen. If the `ConversationListViewController` owned the flush, it would miss events while another screen is active. `ChatCoordinator` is app-scoped for the chat feature; it lives as long as the chat module is active and is the correct owner of cross-screen infrastructure concerns. The same coordinator also handles APNs silent push and `BGAppRefreshTask` registration — all three flush triggers route to the same `FlushPendingMessagesUseCase`.

### Why `MessageLocalDataSource` is Core Data-backed with `NSFetchedResultsController`?

Two reasons — storage scale and stream correctness.

**Storage scale:** a conversation can have 10k+ messages. A `[MessageDTO]` array for the full history would OOM on any real device. Core Data with `fetchBatchSize: 50` faults objects lazily — only the rows visible on screen are in memory at any time.

**Stream correctness:** `NSFetchedResultsController` fires `controllerDidChangeContent` on every insert, update, or delete in its managed object context. Bridging that delegate callback into an `AsyncStream.Continuation` means the ViewModel's message list is always a live projection of what Core Data holds — no separate in-memory array, no dual state, no divergence on relaunch.

The actor boundary is the same as before. The only change is the storage backend inside `MessageLocalDataSource` and the addition of a `observe(conversationId:) -> AsyncStream<[MessageDTO]>` method that sets up the FRC and bridges its delegate.

### Interview Q&A

| Question | Answer |
|---|---|
| Why WebSocket for inbound but HTTP for outbound? | HTTP gives you delivery confirmation, status codes, and idempotency. WebSocket fire-and-forget has none of those guarantees. The direction of the data determines the protocol. |
| Why one socket? | O(1) connections per user. O(conversations) is unsustainable. Channel multiplexing handles any number of conversations on one TCP connection. |
| Why enum for message type, not optionals? | Illegal states become unrepresentable. The cell factory switch is exhaustive at compile time — adding a new type without handling it is a build error, not a runtime crash. |
| What happens if a send fails while offline? | `PendingMessageQueue.enqueue(PendingMessageDTO)` persists it to disk. On next trigger (foreground, APNs push, or BGAppRefreshTask), `ChatCoordinator` calls `FlushPendingMessagesUseCase` which re-sends with the same `clientId` — server deduplicates. |
| Why is `clientId` generated in `SendMessageRequest.init`? | So the same request object always carries the same key. Retries and queue flushes re-use it automatically — no caller needs to track the UUID. |
| What happens when the WebSocket drops? | `WebSocketClient` (CoreKit) handles reconnect internally — `NWPathMonitor` detects `.satisfied`, exponential backoff retries `connect()`, then yields `.connected` on `connectionState`. `MessageRepository` observes that event, fires `GET ?after=lastKnownSeq`, writes to Core Data, and FRC re-yields before re-subscribing to the channel. |
| Why `sequence` on `MessageDTO`? | Ordering, gap detection, and reconnect catch-up all require a monotonic server-assigned sequence. Without it, arrival order is the only ordering signal — unreliable across reconnects. |
| Why Core Data over Realm for messages? | Chat is append-heavy with cursor reads. Core Data's `NSFetchRequest` with `fetchBatchSize` maps directly. `NSFetchedResultsController` bridges naturally into `AsyncStream` for live observation. Realm's live-object model conflicts with Swift actor isolation (`Sendable` requirements) and adds a dependency without benefit here. Realm belongs in FeedApp where live `Results<T>` queries shine. |
| Why two use cases for messages instead of one? | Different execution models. `ObserveMessagesUseCase` returns `AsyncStream<[Message]>` — it never completes. `FetchMessagesUseCase` is `async throws` — it completes immediately. You cannot merge different return types without giving one use case two modes of operation. |
| Why `ObserveMessagesUseCase` instead of `StreamMessagesUseCase`? | `StreamMessages` implied WebSocket as the source — an implementation detail. The domain intent is observation of a live resource. FRC is the stream source; WebSocket is just a write path into Core Data. The name reflects the domain, not the transport. |
| Why does `FetchMessagesUseCase` not return messages to the ViewModel? | It only triggers a remote fetch + Core Data write. `ObserveMessagesUseCase`'s FRC detects the batch insert and re-yields the expanded list. One delivery path — no dual accumulation. |
| How does unread count stay in sync across devices? | `POST /conversations/{id}/read` on open. Server resets the counter and broadcasts `conversation.unread_updated` to all active devices via WebSocket. The conversation list updates reactively — no re-fetch. |
| Why two paths for message delivery (stream vs HTTP catch-up)? | The stream is for low-latency, low-volume real-time events. Catch-up after reconnect can be hundreds of messages — routing that through the stream exhausts the buffer. HTTP catch-up is paginated and retryable; the stream stays clean for live events. |
